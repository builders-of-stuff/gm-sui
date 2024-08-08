<script lang="ts">
  import { fade } from 'svelte/transition';
  import { PUBLIC_NODE_ENV } from '$env/static/public';
  import {
    ConnectButton,
    devnetWalletAdapter,
    walletAdapter as productionWalletAdapter
  } from '@builders-of-stuff/svelte-sui-wallet-adapter';
  import CalHeatmap from 'cal-heatmap';
  import { Transaction } from '@mysten/sui/transactions';
  import { toast } from 'svelte-sonner';
  // @ts-ignore
  import Tooltip from 'cal-heatmap/plugins/Tooltip';

  import 'cal-heatmap/cal-heatmap.css';

  import { Button } from '$lib/components/ui/button/index.js';
  import { Input } from '$lib/components/ui/input/index.js';

  import { getObjectId } from '$lib/shared/shared-tools';
  import { formatTime, linkifyGmId } from '$lib/shared/shared-tools';

  const walletAdapter =
    PUBLIC_NODE_ENV === 'development' ? devnetWalletAdapter : productionWalletAdapter;

  let commitMessage = $state('');
  let gms = $state([]) as any;
  let activelyViewedGms = $state([]) as any;
  let hasFetched = $state(false);

  const isWalletConnected = $derived.by(() => walletAdapter.currentAccount?.address);
  let isCommitEnabled = $derived(
    !!commitMessage && !!walletAdapter.currentAccount?.address
  );
  const showGmsForTheDay = $derived.by(() => {
    return activelyViewedGms.length > 0;
  });
  const activelyViewedGmsDay = $derived.by(() => {
    return activelyViewedGms.length > 0
      ? new Date(parseInt(String(activelyViewedGms[0].timestamp))).toLocaleDateString()
      : '';
  });

  /**
   * e.g. [
    { date: '2024-01-01', value: 3 },
    { date: '2024-04-02', value: 6 },
    { date: '2024-06-02', value: 100 }
  ];
  */
  let gmHeatmapData = $derived.by(() => {
    const heatmapData = Object.values(
      gms?.reduce?.((acc, { date }) => {
        acc[date] = acc[date] || { date, value: 0 };
        acc[date].value++;
        return acc;
      }, {})
    );

    return heatmapData;
  });

  let cal = new CalHeatmap();

  /**
   * Set actively viewed gms
   */
  // https://cal-heatmap.com/docs/events#click
  cal.on('click', (event, timestamp, value) => {
    /**
     * Filter gms based on timestamp (start of day to end of day)
     */
    let startDate = new Date(parseInt(String(timestamp)));
    let endDate = new Date(startDate);
    endDate.setDate(startDate.getDate() + 1);

    let clickedDayGms = gms.filter((item: any) => {
      let itemTimestamp = parseInt(item.timestamp); // Convert string timestamp to number
      return itemTimestamp >= startDate.getTime() && itemTimestamp < endDate.getTime();
    });

    // Sort the filtered results by timestamp in descending order
    clickedDayGms.sort((a, b) => parseInt(b.timestamp) - parseInt(a.timestamp));

    activelyViewedGms = clickedDayGms;
  });

  /**
   * Fetch gms
   */
  const fetchGms = async () => {
    const object = await walletAdapter.suiClient.getObject({
      id: getObjectId('GM_TRACKER_ID'),
      options: {
        showContent: true,
        showDisplay: true,
        showType: true,
        showOwner: true
      }
    });

    const gmsId = object?.data?.content?.fields?.gms?.fields?.id?.id;

    const gmsFields = await walletAdapter.suiClient.getDynamicFields({
      // gms table id
      parentId: gmsId
    });

    let _gms = await Promise.all(
      gmsFields.data.map(async (df) => {
        const gm = await walletAdapter.suiClient.getDynamicFieldObject({
          parentId: gmsId,
          name: df.name
        });

        const gmFields = gm?.data?.content?.fields;
        const gmEpochTimestamp = Number(gmFields?.timestamp);

        const gmDate = gmEpochTimestamp ? new Date(gmEpochTimestamp) : null;

        if (gmDate) {
          const formattedDate = gmDate.toISOString().split('T')[0];

          // Create array of objects keyed by date, with value as a count of GMs on that date
          return {
            ...gmFields,
            date: formattedDate
          };
        }

        return null;
      })
    );

    gms = _gms.filter(Boolean);
    hasFetched = true;
  };

  /**
   * GM commit
   */
  const handleGmCommit = async () => {
    const tx = new Transaction();
    const timestamp = Date.now();

    tx.moveCall({
      target: `${getObjectId('GM_PACKAGE_ID')}::gm::new_gm`,
      arguments: [
        // key,
        tx.pure.string(`testy-${Math.random()}`),
        // message
        tx.pure.string(`${commitMessage}`),
        // timestamp
        tx.pure.u64(timestamp),
        // gm_tracker: &mut GmTracker,
        tx.object(getObjectId('GM_TRACKER_ID')),
        // treasury_cap_holder: &mut TreasuryCapHolder,
        tx.object(getObjectId('TREASURY_CAP_HOLDER_ID'))
      ]
    });

    try {
      const { bytes, signature } = await walletAdapter.signTransaction(tx as any, {});

      const executedTx = await walletAdapter.suiClient.executeTransactionBlock({
        transactionBlock: bytes,
        signature,
        options: {
          showEffects: true,
          showObjectChanges: true,
          showEvents: true
        }
      });

      /**
       * Create mock gm from known data rather than fetch RPC again
       */
      const newGmId = executedTx.effects.created.filter((created) => {
        const owner = created?.owner?.ObjectOwner;
        // const objectId = created?.reference?.objectId;

        // hard-coded for this transaction that has only two created objects in effects, gm being the one owned
        const isGm = executedTx.effects?.created.some(
          (created) => created?.reference?.objectId === owner
        );

        return isGm;
      })[0]?.reference?.objectId;
      const formattedDate = new Date(timestamp).toISOString().split('T')[0];

      let mockCreatedGm = {
        id: {
          id: newGmId
        },
        sender: walletAdapter?.currentAccount?.address,
        message: commitMessage,
        timestamp: Date.now(),
        date: formattedDate
      };
      gms = [...gms, mockCreatedGm];

      commitMessage = '';
      toast.success('gm committed');

      // fetchGms();
    } catch (error: any) {
      console.log('error: ', error);
      toast.error(error?.message);
    }
  };

  /**
   * Update contribution graph
   */
  $effect(() => {
    cal.paint(
      {
        theme: 'light',
        range: 12,
        domain: {
          // Removing gaps between months not possible: https://github.com/wa0x6e/cal-heatmap/issues/184
          type: 'month',
          gutter: 4
        },
        subDomain: {
          type: 'day',
          gutter: 4
        },
        date: {
          start: new Date('2024-01-01'),
          end: new Date('2024-12-31')
        },
        data: {
          source: gmHeatmapData,
          x: 'date',
          y: 'value'
        },
        scale: {
          color: {
            scheme: 'Cool',
            type: 'linear',
            domain: [0, 50]
          }
        }
      },
      // Runs fine, but type issues: https://github.com/wa0x6e/cal-heatmap/issues/520
      // @ts-ignore
      [
        [
          Tooltip,
          {
            enabled: true,
            text: (timestamp: number, value: number) => {
              const date = new Date(timestamp);
              // e.g. 6 GMs on January 6th
              // const formattedDate = DateTime.fromJSDate(date).toFormat('MMMM d');
              // const formattedDate = date.toISOString();
              const formattedDate = date.toISOString().split('T')[0];

              return `${value || 0} GMs on ${formattedDate}`;
            }
          }
        ]
      ]
    );
  });

  /**
   * Fetch gms
   */
  $effect(() => {
    if (!hasFetched) {
      fetchGms();
    }
  });
</script>

<div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
  <!-- Wallet adapter -->
  <div class="mt-2 flex justify-end">
    <ConnectButton {walletAdapter} />
  </div>
  <div class="relative px-6 pb-12 pt-24 sm:rounded-3xl sm:px-24 xl:pb-24 xl:pt-32">
    <!-- Header -->
    <h2
      class="mx-auto max-w-2xl text-center text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl"
    >
      GM Sui
    </h2>

    <!-- Calendar Heatmap -->
    <div id="cal-heatmap" class="mt-4 flex justify-center overflow-x-auto"></div>

    <!-- Text field -->
    {#if isWalletConnected}
      <form transition:fade class="mx-auto mt-10 flex max-w-md gap-x-2">
        <Input
          type="text"
          placeholder="gm"
          class="max-w-xs"
          bind:value={commitMessage}
        />

        <Button onclick={handleGmCommit} disabled={!isCommitEnabled}>Commit</Button>
      </form>
    {/if}
  </div>
</div>

<!-- GMs for selected day -->
{#if showGmsForTheDay}
  <h3 class="text-1xl mb-2 font-medium leading-6 text-gray-900">
    GMs on {activelyViewedGmsDay}
  </h3>

  <div transition:fade class="bg-white p-4">
    <div class="relative border-l border-gray-200">
      {#each activelyViewedGms as item (item.timestamp)}
        <div class="mb-10 ml-4">
          <!-- Date -->
          <div
            class="absolute -left-1.5 mt-1.5 h-3 w-3 rounded-full border border-white bg-indigo-600"
          ></div>
          <time class="mb-1 text-sm font-normal leading-none text-gray-400"
            >{new Date(parseInt(item.timestamp)).toLocaleDateString()} - {formatTime(
              item.timestamp
            )}
          </time>

          <!-- Message -->
          <h3 class="text-lg font-semibold text-gray-900">
            <a
              href={linkifyGmId(item?.id?.id)}
              target="_blank"
              rel="noopener noreferrer"
              class="text-indigo-600 hover:underline"
            >
              {item.message}
            </a>
          </h3>

          <!-- Sender -->
          <p class="text-base font-normal text-gray-500">
            {item.sender.substring(0, 5)}.....{item.sender.substring(
              item.sender.length - 3
            )}
          </p>
        </div>
      {/each}
    </div>
  </div>
{/if}

<!-- Footer  -->
<footer class="fixed bottom-0 right-0 p-4">
  <a
    href="https://github.com/builders-of-stuff/gm-sui"
    target="_blank"
    rel="noopener noreferrer"
    title="Visit our GitHub Repository"
  >
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="currentColor"
      class="h-6 w-6 text-gray-800 hover:text-gray-600"
      viewBox="0 0 16 16"
    >
      <path
        d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.68-.01 1.17.63 1.33.89.77 1.31 2.04.93 2.54.71.08-.56.3-.93.54-1.15-1.77-.2-3.63-.89-3.63-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.31.27.58.79.58 1.59 0 1.15-.01 2.07-.01 2.35 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"
      />
    </svg>
  </a>
</footer>
