<template>
  <div class="audit-logs">
    <h3>Historial de auditoría</h3>
    <div class="filters">
      <label>Tabla: <input v-model="table" placeholder="products, product_variants, inventory_movements" /></label>
      <label>ID registro: <input v-model="recordId" placeholder="uuid" /></label>
      <label>Desde: <input type="date" v-model="since" /></label>
      <label>Hasta: <input type="date" v-model="until" /></label>
      <button @click="load">Filtrar</button>
      <button @click="clearFilters">Limpiar</button>
    </div>

    <div v-if="loading">Cargando...</div>
    <div v-if="error" class="error">{{ error }}</div>

    <table v-if="logs.length" class="table">
      <thead>
        <tr>
          <th>Fecha</th>
          <th>Tabla</th>
          <th>Acción</th>
          <th>Registro</th>
          <th>Usuario</th>
          <th>Old</th>
          <th>New</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="l in logs" :key="l.id">
          <td>{{ formatDate(l.changed_at) }}</td>
          <td>{{ l.table_name }}</td>
          <td>{{ l.action }}</td>
          <td>{{ l.record_id }}</td>
          <td>{{ l.changed_by }}</td>
          <td><pre class="json">{{ pretty(l.old_data) }}</pre></td>
          <td><pre class="json">{{ pretty(l.new_data) }}</pre></td>
        </tr>
      </tbody>
    </table>
    <div v-else>
      Sin resultados.
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue';
import { useAuditStore } from '../../../stores/audit';

const audit = useAuditStore();
const table = ref('');
const recordId = ref('');
const since = ref('');
const until = ref('');

const loading = computed(() => audit.loading);
const error = computed(() => audit.error);
const logs = computed(() => audit.logs);

function pretty(obj) {
  try { return JSON.stringify(obj, null, 2); } catch (e) { return String(obj); }
}

function formatDate(d) { return d ? new Date(d).toLocaleString() : ''; }

async function load() {
  await audit.fetchLogs({
    table_name: table.value || null,
    record_id: recordId.value || null,
    since: since.value || null,
    until: until.value || null,
    limit: 200
  });
}

function clearFilters() {
  table.value = '';
  recordId.value = '';
  since.value = '';
  until.value = '';
  audit.clear();
}

load();
</script>

<style scoped>
.audit-logs .filters { display:flex; gap:8px; flex-wrap:wrap; margin-bottom:12px }
.json { max-height:120px; overflow:auto; background:#f7f7f7; padding:6px }
.table { width:100%; border-collapse:collapse }
.table th, .table td { border:1px solid #ddd; padding:6px }
</style>
