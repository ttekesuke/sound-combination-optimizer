<template>
  <div class="score-shell">
    <div v-if="error" class="score-error">{{ error }}</div>
    <div ref="host" class="score-host" />
  </div>
</template>

<script setup lang="ts">
import { nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { OpenSheetMusicDisplay } from 'opensheetmusicdisplay'

const props = defineProps<{ xml: string }>()
const host = ref<HTMLElement | null>(null)
const error = ref('')
let instance: OpenSheetMusicDisplay | null = null
let revision = 0

async function renderScore() {
  const mine = ++revision
  await nextTick()
  if (!host.value) return
  host.value.innerHTML = ''
  error.value = ''
  if (!props.xml) return
  try {
    const next = new OpenSheetMusicDisplay(host.value, {
      backend: 'svg', autoResize: true, drawTitle: false, drawComposer: false,
      drawCredits: false, disableCursor: true,
    })
    await next.load(props.xml)
    if (mine !== revision) return
    await next.render()
    instance = next
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '楽譜を表示できませんでした'
  }
}

watch(() => props.xml, renderScore, { immediate: true })
onBeforeUnmount(() => { revision += 1; instance?.clear() })
</script>

<style scoped>
.score-shell { min-height: 260px; overflow-x: auto; border-radius: 14px; background: #fff; padding: 16px; }
.score-host { min-width: 760px; }
.score-error { color: #b00020; padding: 16px; }
</style>
