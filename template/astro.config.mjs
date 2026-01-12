// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';
import fs from 'node:fs';
import path from 'node:path';
import yaml from 'js-yaml';

// Load config from YAML at build time
const configPath = path.join(process.cwd(), 'src', 'config', 'config.yaml');
const configFile = fs.readFileSync(configPath, 'utf8');
const config = yaml.load(configFile);

// https://astro.build/config
export default defineConfig({
  site: config.site.url,
  integrations: [sitemap()],
  vite: {
    plugins: [tailwindcss()],
  },
});
