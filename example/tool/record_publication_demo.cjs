const { chromium } = require('playwright');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');

async function main() {
  const root = path.resolve(__dirname, '../..');
  const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'recorder-media-'));
  const browser = await chromium.launch({ headless: true, slowMo: 650 });
  try {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 1000 },
      deviceScaleFactor: 1,
      recordVideo: { dir: temporary, size: { width: 1440, height: 1000 } },
    });
    const page = await context.newPage();
    const video = page.video();
    await page.goto(process.env.DEMO_APP_URL || 'http://localhost:8931');
    await page.locator('flt-semantics-placeholder').evaluate((element) => element.click());
    await page.getByRole('textbox', { name: 'Email', exact: true }).fill('ada@example.invalid');
    await page.getByRole('textbox', { name: 'Note', exact: true }).fill('Fictional M2 demonstration');
    await page.screenshot({ path: path.join(root, 'doc/images/login.png') });
    await page.getByRole('button', { name: 'Open demo account', exact: true }).click();
    await page.getByText('Demo account is open', { exact: true }).waitFor();
    await page.screenshot({ path: path.join(root, 'doc/images/account.png') });
    await page.getByRole('button', { name: 'Fixture and expectation lab', exact: true }).click();
    await page.getByText('No fixture loaded', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Load sample fixture', exact: true }).click();
    await page.getByText('Ada Fixture', { exact: true }).waitFor();
    await page.getByText('Credit: 24.50', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Clear fixture', exact: true }).click();
    await page.getByText('No fixture loaded', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Load sample fixture', exact: true }).click();
    await page.getByText('Quantity: 2', { exact: true }).waitFor();
    await page.screenshot({ path: path.join(root, 'doc/images/fixture-lab.png') });
    await context.close();
    const destination = path.join(root, 'doc/media/example-walkthrough.webm');
    await video.saveAs(destination);
    console.log(`Recorded app walkthrough: ${destination}`);
    console.log(`Size: ${(await fs.stat(destination)).size} bytes`);
    const mobile = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
    const narrow = await mobile.newPage();
    await narrow.goto(process.env.DEMO_APP_URL || 'http://localhost:8931');
    await narrow.locator('flt-semantics-placeholder').evaluate((element) => element.click());
    await narrow.getByRole('button', { name: 'Open demo account', exact: true }).click();
    await narrow.getByRole('button', { name: 'Fixture and expectation lab', exact: true }).click();
    await narrow.getByRole('button', { name: 'Load sample fixture', exact: true }).click();
    await narrow.getByText('Credit: 24.50', { exact: true }).waitFor();
    await narrow.screenshot({ path: path.join(root, 'doc/images/fixture-lab-mobile.png') });
    await mobile.close();
  } finally {
    await browser.close();
    await fs.rm(temporary, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});