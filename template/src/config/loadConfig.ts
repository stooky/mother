/**
 * YAML Config Loader
 * Loads and parses config.yaml for site configuration
 */

import fs from 'node:fs';
import path from 'node:path';
import yaml from 'js-yaml';

export interface NavLink {
  name: string;
  href: string;
}

export interface SiteConfig {
  site: {
    name: string;
    tagline: string;
    description: string;
    url: string;
    defaultOgImage: string;
    themeColor: string;
  };
  contact: {
    email: string;
    phone: string;
    address: {
      street: string;
      city: string;
      state: string;
      zip: string;
      country: string;
    };
  };
  social: {
    facebook: string;
    instagram: string;
    twitter: string;
    linkedin: string;
    youtube: string;
  };
  hours: {
    monday: string;
    tuesday: string;
    wednesday: string;
    thursday: string;
    friday: string;
    saturday: string;
    sunday: string;
  };
  schemaHours: string[];
  geo: {
    latitude: number;
    longitude: number;
    priceRange: string;
    timezone: string;
  };
  google: {
    analyticsId: string;
    mapsEmbedUrl: string;
  };
  navigation: {
    main: NavLink[];
    footer: {
      company: NavLink[];
      legal: NavLink[];
    };
  };
}

let cachedConfig: SiteConfig | null = null;

export function loadConfig(): SiteConfig {
  if (cachedConfig) {
    return cachedConfig;
  }

  const configPath = path.join(process.cwd(), 'src', 'config', 'config.yaml');
  const fileContents = fs.readFileSync(configPath, 'utf8');
  cachedConfig = yaml.load(fileContents) as SiteConfig;

  return cachedConfig;
}

export const config = loadConfig();
