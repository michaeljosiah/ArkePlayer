import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const script = readFileSync(new URL('../apps/arke_player/assets/reader/pagination.js', import.meta.url), 'utf8');
const view = (id, left, right) => ({ id, position: () => ({ left, right }) });
function reader(views, { paginated = true, axis = 'horizontal', width = 412.19049072265625 } = {}) {
  const manager = { isPaginated: paginated, settings: { axis }, bounds: () => ({ left: 0, right: width }), visible: () => views };
  const rendition = {
    manager,
    reports: 0,
    location: null,
    reportLocation() {
      this.reports++;
      this.location = manager.visible()[0]?.id;
      return Promise.resolve(this.location);
    },
  };
  return { rendition };
}

test('Android 2.625 DPR: saves the visible chapter, not its preceding sub-pixel sliver (P5e)', async () => {
  // Actual bounds from the #436 Android emulator reproduction.
  const context = reader([view('chapter-1', -823.047607421875, 0.952392578125), view('chapter-2', 0.9523809552192688, 824.9523809552193)]);
  assert.equal(await runInNewContext(script, context), 'chapter-2');
  assert.equal(context.rendition.location, 'chapter-2');
  assert.deepEqual(context.rendition.manager.visible().map(v => v.id), ['chapter-2']);
});

test('a sliver on the opposite edge is excluded for right-to-left pagination', async () => {
  const context = reader([view('next', 411.3, 824), view('current', -0.7, 411.3)]);
  await runInNewContext(script, context);
  assert.equal(context.rendition.location, 'current');
});

test('two readable chapter pages in a tablet spread remain visible (P27l)', async () => {
  const context = reader([view('first', 0, 412), view('second', 412, 824)], { width: 824 });
  await runInNewContext(script, context);
  assert.deepEqual(context.rendition.manager.visible().map(v => v.id), ['first', 'second']);
});

test('a readable partial page is retained; the next chapter must not skip it', async () => {
  const context = reader([view('first', -400, 12), view('second', 12, 824)]);
  await runInNewContext(script, context);
  assert.equal(context.rendition.location, 'first');
});

test('scrolling and vertical layouts retain their original visibility rules', async () => {
  for (const options of [{ paginated: false }, { axis: 'vertical' }]) {
    const context = reader([view('first', -411, 0.5), view('second', 0.5, 412)], options);
    await runInNewContext(script, context);
    assert.equal(context.rendition.location, 'first');
  }
});

test('empty, single and temporarily unmeasured views do not lose their location', async () => {
  for (const views of [[], [view('only', 0, 0.5)], [view('first', 0, 0.5), view('second', 0.5, 1)]]) {
    const context = reader(views);
    await runInNewContext(script, context);
    assert.deepEqual(context.rendition.manager.visible(), views);
  }
});

test('chapter display callbacks do not wrap or relocate the same manager again', async () => {
  const context = reader([view('first', -411, 0.5), view('second', 0.5, 412)]);
  await runInNewContext(script, context);
  const visible = context.rendition.manager.visible;
  await runInNewContext(script, context);
  assert.equal(context.rendition.manager.visible, visible);
  assert.equal(context.rendition.reports, 1);
});

test('a disposed renderer is ignored', () => assert.doesNotThrow(() => runInNewContext(script, {})));
