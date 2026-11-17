// Renders SVG files to transparent PNGs with headless Chromium (Playwright).
// Usage: node render_svg.js jobs.json   where jobs = [{svg, png, width, height, scale}]
const fs = require('fs');
const { chromium } = require('playwright');

(async () => {
  const jobs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const job of jobs) {
    const scale = job.scale || 1;
    await page.setViewportSize({ width: job.width * scale, height: job.height * scale });
    const svg = fs.readFileSync(job.svg, 'utf8');
    await page.setContent(
      `<html><body style="margin:0;background:transparent;overflow:hidden">` +
      `<div style="width:${job.width * scale}px;height:${job.height * scale}px">` +
      svg.replace('<svg ', `<svg style="width:${job.width * scale}px;height:${job.height * scale}px;display:block" `) +
      `</div></body></html>`);
    await page.screenshot({ path: job.png, omitBackground: true,
      clip: { x: 0, y: 0, width: job.width * scale, height: job.height * scale } });
  }
  await browser.close();
})();
