import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import fs from "fs";
import path from "path";
import { defineConfig } from "vite";

export default defineConfig({
  base: "./",
  plugins: [react(), tailwindcss(), webKitFileUrlCompat()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src")
    }
  },
  build: {
    outDir: "dist",
    emptyOutDir: true
  }
});

function webKitFileUrlCompat() {
  return {
    name: "webkit-file-url-compat",
    writeBundle() {
      const indexPath = path.resolve(__dirname, "dist/index.html");

      if (!fs.existsSync(indexPath)) {
        return;
      }

      let html = fs.readFileSync(indexPath, "utf8")
        .replace(/<script type="module" crossorigin /g, "<script ")
        .replace(/<link rel="stylesheet" crossorigin /g, "<link rel=\"stylesheet\" ");

      const scriptMatch = html.match(/\s*<script src="\.\/assets\/[^"]+\.js"><\/script>/);
      if (scriptMatch) {
        html = html
          .replace(scriptMatch[0], "")
          .replace("</body>", `    ${scriptMatch[0].trim()}\n  </body>`);
      }

      fs.writeFileSync(indexPath, html);
    }
  };
}
