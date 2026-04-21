import { test } from '@playwright/test';

test('home page renders', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('http://localhost:8080', { waitUntil: 'networkidle' });
  await page.screenshot({ path: 'playwright-artifacts/home.png', fullPage: true });
});
