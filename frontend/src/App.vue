<template>
  <v-app>
    <v-app-bar flat height="70" class="app-bar">
      <v-container class="d-flex align-center px-5" fluid>
        <div class="mark">SCO</div>
        <div class="ml-3">
          <div class="text-subtitle-1 font-weight-bold">Sound Combination Optimizer</div>
          <div class="text-caption text-medium-emphasis">target-based acoustic orchestration</div>
        </div>
        <v-spacer />
        <v-chip :color="inventory?.sampleCount ? 'primary' : 'warning'" variant="tonal" size="small">
          <v-icon start icon="mdi-waveform" />
          {{ inventory ? `${inventory.sampleCount} samples / ${inventory.instrumentCount} instruments` : 'library…' }}
        </v-chip>
      </v-container>
    </v-app-bar>

    <v-main>
      <v-container class="page" fluid>
        <section class="hero">
          <div class="eyebrow">TARGET → ANALYSE → ORCHESTRATE</div>
          <h1>音を、演奏可能な音の配置へ。</h1>
          <p>ターゲットWAVをテンポグリッドに分解し、サーバの楽器音サンプルを組み合わせて近似します。</p>
        </section>

        <v-row align="start">
          <v-col cols="12" lg="4">
            <v-card class="panel" rounded="xl" elevation="0">
              <v-card-title class="panel-title"><span class="step">01</span> ターゲット音響</v-card-title>
              <v-card-text>
                <div class="drop-zone" :class="{ active: dragging, ready: targetFile }"
                     @dragover.prevent="dragging = true" @dragleave.prevent="dragging = false" @drop.prevent="onDrop">
                  <input ref="fileInput" type="file" accept="audio/wav,.wav" hidden @change="onPick" />
                  <v-icon :icon="targetFile ? 'mdi-check-circle-outline' : 'mdi-upload-outline'" size="42" />
                  <div class="mt-3 font-weight-medium">{{ targetFile?.name ?? 'WAVをドロップ' }}</div>
                  <div class="text-caption text-medium-emphasis mt-1">
                    {{ targetFile ? formatBytes(targetFile.size) : 'またはファイルを選択' }}
                  </div>
                  <v-btn class="mt-4" variant="tonal" color="primary" @click="fileInput?.click()">選択</v-btn>
                </div>
                <audio v-if="targetUrl" class="player mt-4" :src="targetUrl" controls />
              </v-card-text>
            </v-card>

            <v-card class="panel mt-4" rounded="xl" elevation="0">
              <v-card-title class="panel-title"><span class="step">02</span> 時間と探索</v-card-title>
              <v-card-text>
                <div class="control-label"><span>テンポ</span><strong>{{ tempo }} BPM</strong></div>
                <v-slider v-model="tempo" :min="40" :max="240" :step="1" color="primary" hide-details />
                <div class="control-label mt-5"><span>刻み</span></div>
                <v-btn-toggle v-model="subdivision" mandatory color="primary" variant="outlined" divided class="w-100">
                  <v-btn :value="4" class="flex-grow-1">4分</v-btn>
                  <v-btn :value="8" class="flex-grow-1">8分</v-btn>
                  <v-btn :value="16" class="flex-grow-1">16分</v-btn>
                </v-btn-toggle>
                <div class="control-label mt-5"><span>同時発音数</span><strong>最大 {{ maxVoices }}</strong></div>
                <v-slider v-model="maxVoices" :min="1" :max="8" :step="1" color="secondary" hide-details />

                <v-expansion-panels class="mt-4" variant="accordion">
                  <v-expansion-panel title="探索の詳細設定">
                    <v-expansion-panel-text>
                      <div class="control-label"><span>疎性</span><strong>{{ sparsity.toFixed(3) }}</strong></div>
                      <v-slider v-model="sparsity" :min="0" :max="0.12" :step="0.005" hide-details />
                      <div class="control-label mt-4"><span>音色の連続性</span><strong>{{ continuity.toFixed(3) }}</strong></div>
                      <v-slider v-model="continuity" :min="0" :max="0.15" :step="0.005" hide-details />
                    </v-expansion-panel-text>
                  </v-expansion-panel>
                </v-expansion-panels>

                <v-btn block size="large" color="primary" class="analyse-btn mt-5" :loading="working"
                       :disabled="!targetFile || !inventory?.sampleCount" @click="orchestrate">
                  <v-icon start icon="mdi-auto-fix" /> 楽器配置を探索
                </v-btn>
                <v-alert v-if="error" type="error" variant="tonal" density="compact" class="mt-4">{{ error }}</v-alert>
              </v-card-text>
            </v-card>
          </v-col>

          <v-col cols="12" lg="8">
            <v-card v-if="!result" class="empty-state panel" rounded="xl" elevation="0">
              <div class="orbit"><v-icon icon="mdi-music-clef-treble" size="52" /></div>
              <h2>結果はここに表示されます</h2>
              <p>WAVを選び、テンポと刻みを指定してください。</p>
              <div class="feature-strip">
                <span>log-spectrum</span><span>chroma</span><span>sparse pursuit</span><span>MusicXML</span>
              </div>
            </v-card>

            <template v-else>
              <v-card class="result-head panel" rounded="xl" elevation="0">
                <v-card-text class="d-flex flex-wrap align-center ga-4 pa-5">
                  <div>
                    <div class="eyebrow">RESULT / {{ result.jobId.slice(0, 8) }}</div>
                    <div class="text-h5 font-weight-bold mt-1">{{ result.summary.eventCount }} notes across {{ result.summary.slotCount }} slots</div>
                  </div>
                  <v-spacer />
                  <div class="stat"><small>DURATION</small><strong>{{ result.summary.durationSeconds }}s</strong></div>
                  <div class="stat"><small>GRID</small><strong>1/{{ result.summary.subdivision }}</strong></div>
                  <div class="stat"><small>RESIDUAL</small><strong>{{ result.summary.meanResidual }}</strong></div>
                </v-card-text>
              </v-card>

              <v-row class="mt-1">
                <v-col cols="12" md="6">
                  <v-card class="panel h-100" rounded="xl" elevation="0">
                    <v-card-title class="text-subtitle-1">再構成音響</v-card-title>
                    <v-card-text>
                      <audio class="player" :src="resultAudioUrl" controls />
                      <v-btn variant="text" color="primary" prepend-icon="mdi-download" class="mt-2" @click="downloadAudio">WAVを保存</v-btn>
                    </v-card-text>
                  </v-card>
                </v-col>
                <v-col cols="12" md="6">
                  <v-card class="panel h-100" rounded="xl" elevation="0">
                    <v-card-title class="text-subtitle-1">使用音色</v-card-title>
                    <v-card-text class="d-flex flex-wrap ga-2">
                      <v-chip v-for="name in usedInstruments" :key="name" size="small" color="secondary" variant="tonal">{{ name }}</v-chip>
                    </v-card-text>
                  </v-card>
                </v-col>
              </v-row>

              <v-card class="panel mt-4" rounded="xl" elevation="0">
                <v-card-title class="d-flex align-center">
                  <span>楽譜</span><v-spacer />
                  <v-btn size="small" variant="text" prepend-icon="mdi-download" @click="downloadXml">MusicXML</v-btn>
                </v-card-title>
                <v-card-text><ScoreView :xml="result.musicXml" /></v-card-text>
              </v-card>

              <v-card class="panel mt-4" rounded="xl" elevation="0">
                <v-card-title>配置イベント</v-card-title>
                <v-card-text>
                  <div class="timeline">
                    <div v-for="slot in slots" :key="slot.slot" class="slot">
                      <div class="slot-index">{{ slot.slot }}</div>
                      <div class="slot-events">
                        <div v-for="event in slot.events" :key="`${event.instrument}-${event.midi}`" class="event-pill">
                          <strong>{{ event.instrument }}</strong><span>{{ event.note }}</span><small>{{ event.dynamic }}</small>
                        </div>
                      </div>
                    </div>
                  </div>
                </v-card-text>
              </v-card>
            </template>
          </v-col>
        </v-row>
      </v-container>
    </v-main>
  </v-app>
</template>

<script setup lang="ts">
import axios from 'axios'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import ScoreView from './components/ScoreView.vue'

interface Inventory { sampleCount: number; instrumentCount: number; instruments: string[] }
interface EventItem { slot: number; instrument: string; note: string; midi: number; dynamic: string; gain: number }
interface Result {
  jobId: string; audioBase64: string; audioMime: string; musicXml: string; events: EventItem[]
  summary: { eventCount: number; slotCount: number; durationSeconds: number; subdivision: number; meanResidual: number }
}

const inventory = ref<Inventory | null>(null)
const targetFile = ref<File | null>(null)
const targetUrl = ref('')
const result = ref<Result | null>(null)
const working = ref(false)
const error = ref('')
const dragging = ref(false)
const fileInput = ref<HTMLInputElement | null>(null)
const tempo = ref(120)
const subdivision = ref(8)
const maxVoices = ref(4)
const sparsity = ref(0.025)
const continuity = ref(0.04)

const resultAudioUrl = computed(() => result.value ? `data:${result.value.audioMime};base64,${result.value.audioBase64}` : '')
const usedInstruments = computed(() => [...new Set(result.value?.events.map(event => event.instrument) ?? [])].sort())
const slots = computed(() => {
  const groups = new Map<number, EventItem[]>()
  for (const event of result.value?.events ?? []) groups.set(event.slot, [...(groups.get(event.slot) ?? []), event])
  return Array.from({ length: result.value?.summary.slotCount ?? 0 }, (_, index) => ({ slot: index + 1, events: groups.get(index + 1) ?? [] }))
})

onMounted(async () => {
  try { inventory.value = (await axios.get('/api/inventory')).data }
  catch { error.value = 'サーバの音源ライブラリを確認できませんでした。' }
})
onBeforeUnmount(() => { if (targetUrl.value) URL.revokeObjectURL(targetUrl.value) })

function setFile(file?: File) {
  dragging.value = false
  if (!file) return
  if (!file.name.toLowerCase().endsWith('.wav')) { error.value = '現在の入力形式はWAVのみです。'; return }
  if (targetUrl.value) URL.revokeObjectURL(targetUrl.value)
  targetFile.value = file
  targetUrl.value = URL.createObjectURL(file)
  result.value = null
  error.value = ''
}
function onDrop(event: DragEvent) { setFile(event.dataTransfer?.files?.[0]) }
function onPick(event: Event) { setFile((event.target as HTMLInputElement).files?.[0]) }
function formatBytes(value: number) { return value < 1024 * 1024 ? `${(value / 1024).toFixed(1)} KB` : `${(value / 1024 / 1024).toFixed(1)} MB` }

function fileAsBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onerror = () => reject(reader.error)
    reader.onload = () => resolve(String(reader.result).split(',', 2)[1] ?? '')
    reader.readAsDataURL(file)
  })
}

async function orchestrate() {
  if (!targetFile.value) return
  working.value = true; error.value = ''; result.value = null
  try {
    const audioBase64 = await fileAsBase64(targetFile.value)
    const response = await axios.post('/api/orchestrate', {
      audioBase64, tempo: tempo.value, subdivision: subdivision.value,
      maxVoices: maxVoices.value, sparsity: sparsity.value, continuity: continuity.value,
    }, { timeout: 10 * 60 * 1000 })
    result.value = response.data
  } catch (cause: any) {
    error.value = cause?.response?.data?.message ?? cause?.message ?? '探索に失敗しました。'
  } finally { working.value = false }
}

function downloadData(data: string, type: string, filename: string, base64 = false) {
  const href = base64 ? `data:${type};base64,${data}` : URL.createObjectURL(new Blob([data], { type }))
  const anchor = document.createElement('a'); anchor.href = href; anchor.download = filename; anchor.click()
  if (!base64) URL.revokeObjectURL(href)
}
function downloadAudio() { if (result.value) downloadData(result.value.audioBase64, 'audio/wav', 'orchestration.wav', true) }
function downloadXml() { if (result.value) downloadData(result.value.musicXml, 'application/vnd.recordare.musicxml+xml', 'orchestration.musicxml') }
</script>

<style>
:root { color-scheme: dark; font-family: Inter, "Noto Sans JP", system-ui, sans-serif; }
body { margin: 0; background: #10131a; }
.app-bar { background: rgba(16, 19, 26, .9) !important; border-bottom: 1px solid rgba(255,255,255,.08); backdrop-filter: blur(18px); }
.mark { display:grid; place-items:center; width:38px; height:38px; border:1px solid #8be8c4; border-radius:12px; color:#8be8c4; font-size:11px; font-weight:800; letter-spacing:.08em; }
.page { max-width: 1500px; padding: 38px 34px 80px !important; }
.hero { max-width: 820px; margin: 10px 0 34px; }
.hero h1 { font-size: clamp(2rem, 4vw, 4.1rem); line-height: 1.08; letter-spacing: -.045em; margin: 10px 0 14px; }
.hero p { color: #aab2c0; font-size: 1.05rem; }
.eyebrow { color:#8be8c4; font-size:.69rem; font-weight:800; letter-spacing:.16em; }
.panel { background: #181d27 !important; border: 1px solid rgba(255,255,255,.075) !important; }
.panel-title { display:flex; align-items:center; gap:10px; font-size:1rem !important; }
.step { color:#8be8c4; font: 700 .7rem/1 monospace; border:1px solid rgba(139,232,196,.4); padding:6px; border-radius:7px; }
.drop-zone { border: 1px dashed #4c566b; border-radius: 18px; padding: 32px 18px; text-align:center; color:#aab2c0; transition:.2s ease; }
.drop-zone.active, .drop-zone.ready { border-color:#8be8c4; background:rgba(139,232,196,.06); color:#d8fff0; }
.player { width:100%; height:42px; }
.control-label { display:flex; justify-content:space-between; align-items:baseline; color:#b7bfcc; font-size:.85rem; }
.control-label strong { color:#fff; font-family:ui-monospace, monospace; }
.analyse-btn { color:#0c2a20 !important; font-weight:800 !important; }
.empty-state { min-height: 625px; display:flex !important; flex-direction:column; align-items:center; justify-content:center; text-align:center; color:#aab2c0; }
.empty-state h2 { color:#eef2f8; margin:22px 0 6px; }
.orbit { display:grid; place-items:center; width:116px; height:116px; border-radius:50%; color:#8be8c4; border:1px solid rgba(139,232,196,.35); box-shadow:0 0 0 18px rgba(139,232,196,.035), 0 0 0 38px rgba(139,232,196,.018); }
.feature-strip { display:flex; flex-wrap:wrap; justify-content:center; gap:8px; margin-top:28px; }
.feature-strip span { padding:5px 9px; border-radius:99px; background:#222936; font:600 .65rem/1.2 ui-monospace,monospace; }
.stat { min-width:88px; display:flex; flex-direction:column; }
.stat small { color:#7f8999; letter-spacing:.1em; font-size:.6rem; }
.stat strong { font:700 .92rem/1.6 ui-monospace,monospace; }
.timeline { overflow:auto; max-height:430px; border-top:1px solid rgba(255,255,255,.08); }
.slot { display:grid; grid-template-columns:54px 1fr; min-height:52px; border-bottom:1px solid rgba(255,255,255,.06); }
.slot-index { display:grid; place-items:center; color:#697487; font:700 .72rem ui-monospace,monospace; border-right:1px solid rgba(255,255,255,.06); }
.slot-events { display:flex; flex-wrap:wrap; align-items:center; gap:7px; padding:8px 12px; }
.event-pill { display:flex; align-items:baseline; gap:7px; padding:6px 9px; border-radius:8px; background:#232b39; border-left:2px solid #e9b872; font-size:.72rem; }
.event-pill span { color:#e9b872; font-weight:700; }.event-pill small { color:#8994a5; }
@media (max-width: 700px) { .page{padding:24px 14px 50px!important}.hero h1{font-size:2.35rem}.app-bar .text-caption{display:none}.stat{min-width:70px}.result-head .v-card-text{align-items:flex-start!important} }
</style>
