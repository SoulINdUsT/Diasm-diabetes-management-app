// src/modules/education/education.validator.js
import { z } from 'zod';

// For creating content via scripts / admin (you already used category_code)
export const CreateContentSchema = z.object({
  category_code: z.string().min(2),
  title_en: z.string().min(3),
  body_en: z.string().min(10),
  title_bn: z.string().optional().nullable(),
  body_bn: z.string().optional().nullable(),
  media_type: z.enum(['text', 'video', 'image']).default('text'),
  media_url: z.string().url().optional().nullable(),
});

// For listing contents – **very permissive** on query params
export const ListContentsQuery = z
  .object({
    lang: z.enum(['en', 'bn']).default('en'),
    category: z.string().min(2).optional(), // e.g. DIABETES_BASICS
    q: z.string().min(1).optional(),        // search string
    limit: z.coerce.number().min(1).max(100).optional(),
    offset: z.coerce.number().min(0).optional(),
  })
  .passthrough(); // ignore unknown query keys (so ?lang=en alone never fails)
