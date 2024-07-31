<script lang="ts">
  import {
    ConnectButton,
    walletAdapter
  } from '@builders-of-stuff/svelte-sui-wallet-adapter';
  import CalHeatmap from 'cal-heatmap';
  import { DateTime } from 'luxon';
  import { Transaction } from '@mysten/sui/transactions';
  import { toast } from 'svelte-sonner';
  // @ts-ignore
  import Tooltip from 'cal-heatmap/plugins/Tooltip';

  import 'cal-heatmap/cal-heatmap.css';

  import { Button } from '$lib/components/ui/button/index.js';
  import { Input } from '$lib/components/ui/input/index.js';

  import { GM_PACKAGE_ID, GM_TRACKER_ID } from '$lib/shared/shared.constant';

  let commitMessage = $state('');
  let isCommitEnabled = $derived(!!commitMessage && !!walletAdapter.currentAccount);
  let gms = $state([]) as any;
  let hasFetched = $state(false);

  // let gmHeatmapData = [
  //   { date: '2024-01-01', value: 3 },
  //   { date: '2024-04-02', value: 6 },
  //   { date: '2024-06-02', value: 100 }
  // ];
  let gmHeatmapData = $derived.by(() => {
    const what = Object.values(
      gms?.reduce?.((acc, { date }) => {
        acc[date] = acc[date] || { date, value: 0 };
        acc[date].value++;
        return acc;
      }, {})
    );

    return what;
  });

  let cal = new CalHeatmap();

  $inspect(gmHeatmapData);

  /**
   * Fetch gms
   */
  const fetchGms = async () => {
    const object = await walletAdapter.suiClient.getObject({
      id: GM_TRACKER_ID,
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
      target: `${GM_PACKAGE_ID}::gm::new_gm`,
      arguments: [
        // key,
        tx.pure.string(`testy-${Math.random()}`),
        // message
        tx.pure.string(`${commitMessage}`),
        // timestamp
        tx.pure.u64(timestamp),
        // gm_tracker: &mut GmTracker,
        tx.object(GM_TRACKER_ID)
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
        sender: walletAdapter.currentAccount,
        message: commitMessage,
        timestamp: Date.now(),
        date: formattedDate
      };
      gms = [...gms, mockCreatedGm];

      commitMessage = '';
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
  <div class="relative px-6 py-24 sm:rounded-3xl sm:px-24 xl:py-32">
    <!-- Header -->
    <h2
      class="mx-auto max-w-2xl text-center text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl"
    >
      GM Sui
    </h2>

    <!-- Calendar Heatmap -->
    <div id="cal-heatmap" class="mt-4 flex justify-center"></div>

    <!-- Text field -->
    <form class="mx-auto mt-10 flex max-w-md gap-x-4">
      <Input type="text" placeholder="gm" class="max-w-xs" bind:value={commitMessage} />

      <Button onclick={handleGmCommit} disabled={!isCommitEnabled}>Commit</Button>
      <!-- <Button onclick={fetchGms} disabled={!walletAdapter.currentAccount}
        >Fetch gms</Button
      > -->
    </form>
  </div>
</div>
