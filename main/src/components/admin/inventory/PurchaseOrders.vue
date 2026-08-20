<template>
  <div class="admin-page">
    <!-- <header class="page-header">
      <h1>Órdenes de Compra</h1>
    </header> -->
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { storeToRefs } from 'pinia'
import { useInventoryStore } from '../../../stores/inventory'
import { formatCurrency } from '../../../utils/formatCurrency'

defineOptions({ name: 'PurchaseOrders' });

const store = useInventoryStore();
const { suppliers, inventory, purchaseOrders } = storeToRefs(store);
// ...
</script>