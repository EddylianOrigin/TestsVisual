// capture.js
// Usage: node capture.js <startUrl> <outDir> [maxPages] [sameOriginOnly]
// Example: node capture.js https://yello.de C:\Tests\run1 100 true

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const url = require('url');

(async () => {
    const startUrl = process.argv[2];
    const outDir = process.argv[3];
    const maxPages = parseInt(process.argv[4] || '100', 10);
    const sameOriginOnly = (process.argv[5] || 'true') === 'true';

    if (!startUrl || !outDir) {
        console.error('Usage: node capture.js <startUrl> <outDir> [maxPages] [sameOriginOnly]');
        process.exit(2);
    }

    if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    const origin = new URL(startUrl).origin;

    const toVisit = [startUrl];
    const visited = new Set();

    function sanitizeFilename(s) {
        return s.replace(/[:\/\\?&=#%<>|"]/g, '_').slice(0, 200);
    }

    while (toVisit.length && visited.size < maxPages) {
        const current = toVisit.shift();
        if (!current || visited.has(current)) continue;
        try {
            await page.goto(current, { waitUntil: 'domcontentloaded', timeout: 60000 });
            await page.waitForLoadState('networkidle', { timeout: 60000 }).catch(() => { });
            // optional extra wait for dynamic content
            await page.waitForTimeout(1000);

            // full page screenshot
            const filename = sanitizeFilename(new URL(current).pathname + (new URL(current).search || '')) || 'root';
            const outPath = path.join(outDir, `${filename}.png`);
            await page.screenshot({ path: outPath, fullPage: true });
            console.log('Captured:', current, '->', outPath);

            visited.add(current);

            // extract links
            const anchors = await page.$$eval('a[href]', as => as.map(a => a.getAttribute('href')));
            for (let href of anchors) {
                if (!href) continue;
                try {
                    const resolved = new URL(href, current).toString();
                    if (sameOriginOnly && new URL(resolved).origin !== origin) continue;
                    if (!visited.has(resolved) && !toVisit.includes(resolved)) {
                        toVisit.push(resolved);
                    }
                } catch (e) { /* ignore invalid URLs */ }
                if (visited.size + toVisit.length >= maxPages) break;
            }
        } catch (err) {
            console.warn('Error capturing', current, err.message || err);
            visited.add(current);
        }
    }

    await browser.close();
    console.log('Done. Captured', visited.size, 'pages.');
})();
