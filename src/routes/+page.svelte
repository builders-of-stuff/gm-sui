<script lang="ts">
  import { browser } from '$app/environment';
  import {
    ConnectButton,
    walletAdapter
  } from '@builders-of-stuff/svelte-sui-wallet-adapter';
  import CalHeatmap from 'cal-heatmap';
  import 'cal-heatmap/cal-heatmap.css';

  import { Button } from '$lib/components/ui/button/index.js';
  import { Input } from '$lib/components/ui/input/index.js';

  let commitMessage = $state('');

  if (browser) {
    const cal = new CalHeatmap();
    cal.paint({});
  }
</script>

<div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
  <div class="mt-2 flex justify-end">
    <ConnectButton {walletAdapter} />
  </div>
  <div class="relative px-6 py-24 sm:rounded-3xl sm:px-24 xl:py-32">
    <h2
      class="mx-auto max-w-2xl text-center text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl"
    >
      GM Sui
    </h2>

    <div id="cal-heatmap" class="mt-4 flex justify-center"></div>
    <form class="mx-auto mt-10 flex max-w-md gap-x-4">
      <Input
        type="email"
        placeholder="gm"
        class="max-w-xs"
        bind:value={commitMessage}
      />

      <Button disabled={!commitMessage}>Commit</Button>
    </form>
  </div>
</div>
