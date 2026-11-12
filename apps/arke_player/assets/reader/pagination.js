// P5e: at Android's fractional device scale, a preceding chapter can overlap the
// viewport by less than one CSS pixel. epub.js counts that sliver as the first
// visible section and saves its CFI instead of the page the reader is seeing.
(() => {
  const manager = globalThis.rendition?.manager;
  if (!manager || manager.arkePaginationFixed) return;
  const visible = manager.visible;
  manager.visible = function () {
    const views = visible.call(this);
    if (!this.isPaginated || this.settings.axis !== 'horizontal' || views.length < 2) return views;
    const viewport = this.bounds();
    const readable = views.filter(view => {
      const bounds = view.position();
      return Math.min(bounds.right, viewport.right) - Math.max(bounds.left, viewport.left) > 1;
    });
    return readable.length ? readable : views;
  };
  manager.arkePaginationFixed = true;
  return globalThis.rendition.reportLocation();
})();
