// Pure HTML dropdown (native <select> renders badly / can crash in RedM CEF)
Vue.component('dropdown', {
  template: '#dropdown_template',
  props: ['options', 'value'],
  data() {
    return { open: false };
  },
  computed: {
    currentLabel() {
      const o = (this.options || []).find(x => x.value === this.value);
      return o ? o.label : '';
    },
  },
  mounted() {
    this.outside = (e) => { if (!this.$el.contains(e.target)) this.open = false; };
    document.addEventListener('mousedown', this.outside);
  },
  destroyed() {
    document.removeEventListener('mousedown', this.outside);
  },
  methods: {
    pick(v) {
      this.$emit('input', v);
      this.open = false;
    },
  },
});
