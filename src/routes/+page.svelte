<script lang="ts">
  import {
    ConnectButton,
    walletAdapter
  } from '@builders-of-stuff/svelte-sui-wallet-adapter';
  import CalHeatmap from 'cal-heatmap';
  import { DateTime } from 'luxon';
  import { Transaction } from '@mysten/sui/transactions';
  // @ts-ignore
  import Tooltip from 'cal-heatmap/plugins/Tooltip';

  import 'cal-heatmap/cal-heatmap.css';

  import { Button } from '$lib/components/ui/button/index.js';
  import { Input } from '$lib/components/ui/input/index.js';
  import { toast } from 'svelte-sonner';

  import { GM_PACKAGE_ID, GM_TRACKER_ID } from '$lib/shared/shared.constant';

  let commitMessage = $state('');
  let isCommitEnabled = $derived(!!commitMessage && !!walletAdapter.currentAccount);
  let showToast = $state(false);

  let gmData = [
    { date: '2024-01-01', value: 3 },
    { date: '2024-04-02', value: 6 },
    { date: '2024-06-02', value: 100 }
  ];

  const cal = new CalHeatmap();
  cal.paint(
    {
      theme: 'light',
      range: 12,
      domain: {
        // Gaps between months not possible: https://github.com/wa0x6e/cal-heatmap/issues/184
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
        source: gmData,
        x: 'date',
        y: 'value'
      },
      scale: {
        color: {
          scheme: 'Cool',
          type: 'linear',
          domain: [0, 30]
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
            const formattedDate = DateTime.fromJSDate(date).toFormat('MMMM d');

            return `${value || 0} GMs on ${formattedDate}`;
          }
        }
      ]
    ]
  );

  const handleGmCommit = async () => {
    const tx = new Transaction();

    tx.moveCall({
      target: `${GM_PACKAGE_ID}::gm::new_gm`,
      arguments: [
        // key,
        tx.pure.string(`testy-${Math.random()}`),
        // message
        tx.pure.string(`${commitMessage}`),
        // timezone
        tx.pure.string('UTC'),
        // gm_tracker: &mut GmTracker,
        tx.object(GM_TRACKER_ID)
      ]
    });

    const { bytes, signature } = await walletAdapter.signTransaction(tx as any, {});

    try {
      const executedTx = await walletAdapter.suiClient.executeTransactionBlock({
        transactionBlock: bytes,
        signature,
        options: {
          showRawEffects: true
        }
      });

      toast.success('gm committed');
      commitMessage = '';

      console.log('executedTx: ', executedTx);
    } catch (error: any) {
      console.log('error: ', error);
      toast.error(error?.message);
    }
  };
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
    </form>
  </div>
</div>
