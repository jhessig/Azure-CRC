// @ts-check
const { test, expect } = require('@playwright/test');
const SITE_URL = process.env.SITE_URL;
console.log(SITE_URL);

test('has title', async ({ page }) => {
  await page.goto(SITE_URL);

  // Expect a title "to contain" a substring.
  await expect(page).toHaveTitle(/Jeremy Hessig/);
});

//test('get started link', async ({ page }) => {
  //await page.goto('https://playwright.dev/');

  // Click the get started link.
  //await page.getByRole('link', { name: 'Get started' }).click();

  // Expects page to have a heading with the name of Installation.
  //await expect(page.getByRole('heading', { name: 'Installation' })).toBeVisible();
//});
