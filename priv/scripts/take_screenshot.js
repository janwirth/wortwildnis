const puppeteer = require("puppeteer");

async function takeScreenshot(html, width, height) {
  let browser;
  try {
    browser = await puppeteer.launch({
      headless: true,
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });

    const page = await browser.newPage();
    await page.setViewport({
      width: parseInt(width),
      height: parseInt(height),
    });
    await page.setContent(html, { waitUntil: "networkidle0" });

    const screenshot = await page.screenshot({
      type: "png",
      clip: {
        x: 0,
        y: 0,
        width: parseInt(width),
        height: parseInt(height),
      },
    });

    await browser.close();

    return {
      success: true,
      data: screenshot.toString("base64"),
    };
  } catch (error) {
    if (browser) {
      await browser.close();
    }
    return {
      success: false,
      error: error.message,
    };
  }
}

// Read input from command line arguments
const html = process.argv[2];
const width = process.argv[3] || 1200;
const height = process.argv[4] || 630;

takeScreenshot(html, width, height)
  .then((result) => {
    console.log(JSON.stringify(result));
    process.exit(result.success ? 0 : 1);
  })
  .catch((error) => {
    console.log(
      JSON.stringify({
        success: false,
        error: error.message,
      })
    );
    process.exit(1);
  });






