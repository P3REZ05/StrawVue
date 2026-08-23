import { defineStore } from 'pinia';
import { supabase } from '../lib/supabase';

export const useAuditStore = defineStore('audit', {
  state: () => ({
    logs: [],
    loading: false,
    error: null,
  }),
  actions: {
    async fetchLogs({ table_name = null, record_id = null, since = null, until = null, limit = 100 } = {}) {
      this.loading = true;
      this.error = null;
      try {
        let query = supabase.from('audit_logs').select('*').order('changed_at', { ascending: false }).limit(limit);
        if (table_name) query = query.eq('table_name', table_name);
        if (record_id) query = query.eq('record_id', record_id);
        if (since) query = query.gte('changed_at', since);
        if (until) query = query.lte('changed_at', until);
        const { data, error } = await query;
        if (error) throw error;
        this.logs = data;
        return data;
      } catch (err) {
        this.error = err.message || String(err);
        return null;
      } finally {
        this.loading = false;
      }
    },
    clear() {
      this.logs = [];
      this.error = null;
    }
  }
});
