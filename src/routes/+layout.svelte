<script>
  import { Toaster } from '$lib/components/ui/sonner';
  import '../app.css';
</script>

<div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
  <slot></slot>
</div>

<Toaster />
