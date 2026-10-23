'use strict';

const MIME = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif']);
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

class ValidationError extends Error {}

function str(v, field, max, { required = false } = {}) {
  if (v === undefined || v === null || v === '') {
    if (required) throw new ValidationError(`${field} is required`);
    return '';
  }
  if (typeof v !== 'string') throw new ValidationError(`${field} must be a string`);
  const t = v.trim();
  if (required && !t) throw new ValidationError(`${field} is required`);
  if (t.length > max) throw new ValidationError(`${field} is too long (max ${max})`);
  return t;
}

/** Validate and normalize a /api/diagnose body. Throws ValidationError. */
function validateDiagnose(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw new ValidationError('body must be a JSON object');
  }
  const plantName = str(body.plantName, 'plantName', 100, { required: true });

  const sunHrs = Number(body.sunHrs);
  if (body.sunHrs === undefined || body.sunHrs === null || !Number.isFinite(sunHrs) || sunHrs < 0 || sunHrs > 12) {
    throw new ValidationError('sunHrs must be a number between 0 and 12');
  }

  let symptoms = [];
  if (body.symptoms !== undefined) {
    if (!Array.isArray(body.symptoms)) throw new ValidationError('symptoms must be an array');
    if (body.symptoms.length > 20) throw new ValidationError('too many symptoms (max 20)');
    symptoms = body.symptoms.map((s, i) => str(s, `symptoms[${i}]`, 100, { required: true }));
  }

  const notes = str(body.notes, 'notes', 1000);

  let photoBase64 = '';
  let photoMime = 'image/jpeg';
  if (body.photoBase64) {
    if (typeof body.photoBase64 !== 'string') throw new ValidationError('photoBase64 must be a string');
    photoBase64 = body.photoBase64.replace(/^data:[^;]+;base64,/, '');
    if (!/^[A-Za-z0-9+/]+={0,2}$/.test(photoBase64)) throw new ValidationError('photoBase64 is not valid base64');
    if (Math.floor((photoBase64.length * 3) / 4) > MAX_PHOTO_BYTES) {
      throw new ValidationError('photo is too large (max 5 MB)');
    }
    if (body.photoMime !== undefined) {
      if (!MIME.has(body.photoMime)) throw new ValidationError('photoMime must be jpeg, png, webp or gif');
      photoMime = body.photoMime;
    }
  }

  if (!symptoms.length && !notes && !photoBase64) {
    throw new ValidationError('give at least one symptom, a note, or a photo');
  }

  return { plantName, sunHrs, symptoms, notes, photoBase64, photoMime };
}

module.exports = { validateDiagnose, ValidationError, MAX_PHOTO_BYTES };
