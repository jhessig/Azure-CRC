// @ts-check
const { test, expect } = require('@playwright/test');
const SITE_URL = process.env.SITE_URL;
const NOT_FOUND_URL = SITE_URL + '/404.html';
console.log(SITE_URL);

async function mockVisitorCount(page, { count = 123, fail = false } = {}) {
  await page.route('**/api/visitor_count', route => {
    if (fail) {
      route.fulfill({
        status: 500,
        body: JSON.stringify({ error: "Server error" }),
        headers: { 'Content-Type': 'application/json' }
      });
    } else {
      route.fulfill({
        status: 200,
        body: JSON.stringify({ count }),
        headers: { 'Content-Type': 'application/json' }
      });
    }
  });
}

test.describe('Resume App', () => {
  test('Index loads essential content and visitor count', async ({ page }) => {
    await mockVisitorCount(page, { count: 321 });
    await page.goto(SITE_URL);

    // Check banner name and role
    await expect(page.getByRole('heading', { name: /Jeremy Hessig/i })).toBeVisible();
    await expect(page.getByRole('heading', { name: /Cloud Engineer/i })).toBeVisible();

    // Contact Me link
    await expect(page.getByRole('link', { name: /Contact Me/i })).toHaveAttribute('href', /mailto:/);

    // // Links to GitHub and LinkedIn
    // await expect(page.getByRole('link', { name: /github/i })).toHaveAttribute('href', /github/);
    // await expect(page.getByRole('link', { name: /linkedin/i })).toHaveAttribute('href', /linkedin/);

    // Education section
    await expect(page.getByText(/Education/, { exact: false })).toBeVisible();

    // Certifications section with image and link
    await expect(page.getByRole('heading', { name: /Certifications/i })).toBeVisible();
    await expect(page.getByRole('img', { name: /Azure Administrator Associate/i })).toBeVisible();

    // Visitor count is filled in from mock
    await expect(page.locator('#count')).toHaveText('321');
  });

  test('Visitor count handles API failure', async ({ page }) => {
    await mockVisitorCount(page, { fail: true });
    await page.goto(SITE_URL);
    await expect(page.locator('#count')).toHaveText(/Error loading count/i);
  });

  test('404 page displays correctly and home navigation works', async ({ page }) => {
    await page.goto(NOT_FOUND_URL);

    // Big 404
    await expect(page.getByRole('heading', { name: '404' })).toBeVisible();

    // Message and Back to Home
    await expect(page.getByText(/Page Not Found/i)).toBeVisible();
    await expect(page.getByText(/doesn't exist/, { exact: false })).toBeVisible();

    // Back to Home button
    const backBtn = page.getByRole('link', { name: /Back to Home/i });
    await expect(backBtn).toHaveAttribute('href', /index\.html/);
    // Optionally click and verify navigation (uncomment next lines if you wish)
    // await backBtn.click();
    // await expect(page).toHaveURL(/index\.html/);
  });

  // test('Visual regression snapshot for 404 page', async ({ page }) => {
  //   await page.goto(NOT_FOUND_URL);
  //   await expect(page).toHaveScreenshot('404-page.png');
  // });
});
