/**
 * Site Configuration
 * Loads settings from config.yaml
 */

import { config } from './loadConfig';

export const siteConfig = {
  // Basic Info
  name: config.site.name,
  tagline: config.site.tagline,
  description: config.site.description,
  url: config.site.url,

  // Contact Information
  contact: {
    email: config.contact.email,
    phone: config.contact.phone,
    address: {
      street: config.contact.address.street,
      city: config.contact.address.city,
      state: config.contact.address.state,
      zip: config.contact.address.zip,
      country: config.contact.address.country,
    },
  },

  // Social Media Links
  social: {
    twitter: config.social.twitter,
    linkedin: config.social.linkedin,
    facebook: config.social.facebook,
    instagram: config.social.instagram,
    youtube: config.social.youtube,
  },

  // Business Hours
  hours: {
    monday: config.hours.monday,
    tuesday: config.hours.tuesday,
    wednesday: config.hours.wednesday,
    thursday: config.hours.thursday,
    friday: config.hours.friday,
    saturday: config.hours.saturday,
    sunday: config.hours.sunday,
  },

  // Navigation Links
  navigation: config.navigation.main,

  // Footer Navigation
  footerLinks: {
    company: config.navigation.footer.company,
    legal: config.navigation.footer.legal,
  },

  // Default SEO Image
  defaultOgImage: config.site.defaultOgImage,

  // Google Analytics ID
  googleAnalyticsId: config.google.analyticsId,

  // Theme color
  themeColor: config.site.themeColor,

  // Geo/Location data
  geo: config.geo,

  // Schema hours for structured data
  schemaHours: config.schemaHours,

  // Google Maps embed URL
  googleMapsEmbedUrl: config.google.mapsEmbedUrl,

  // Copyright
  copyright: `© ${new Date().getFullYear()} ${config.site.name}. All rights reserved.`,
};

export type SiteConfig = typeof siteConfig;
