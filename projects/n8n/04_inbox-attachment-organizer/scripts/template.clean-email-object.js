// Clean Email object - Smart dual-extraction for n8n Code node
// Handles both Google One (text=footer only) and Digitec (text=HTML) cases
// Copy this code into the "Clean Email object" Code node in inbox-attachment-organizer workflow

const items = $input.all();
const gmail = $('Gmail').first().json;

// Helper: strip HTML tags and decode entities
function stripHtml(str) {
  return str
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<!--[\s\S]*?-->/gi, '')
    .replace(/<\/(p|div|tr|li|h[1-6])>/gi, '\n')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&#\d+;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// Helper: detect if string contains HTML tags
function containsHtml(str) {
  return /<(table|tr|td|div|span|p|a|br|img|style|script)\b/i.test(str);
}

// Helper: normalize for comparison
function normalize(str) {
  return str.toLowerCase().replace(/\s+/g, ' ').trim();
}

// 1. Extract and clean from both sources
const rawText = gmail.text || '';
const rawHtml = gmail.html || '';

// Clean text - strip HTML if it contains HTML tags (Digitec case)
const textContent = containsHtml(rawText) ? stripHtml(rawText) : rawText.trim();
// Clean HTML
const htmlContent = rawHtml ? stripHtml(rawHtml) : '';

// 2. Determine what to use (smart dual-extraction)
let rawEmailText;

if (!textContent && !htmlContent) {
  rawEmailText = '';
} else if (!htmlContent) {
  rawEmailText = textContent;
} else if (!textContent) {
  rawEmailText = htmlContent;
} else {
  const normalizedText = normalize(textContent);
  const normalizedHtml = normalize(htmlContent);

  // Helper: check if content A is contained in content B using fuzzy word matching
  function isContentSubset(contentA, contentB) {
    const normalizedA = normalize(contentA);
    const normalizedB = normalize(contentB);

    // First try exact substring
    if (normalizedB.includes(normalizedA)) return true;

    // Fuzzy: check if 80%+ of A's significant words appear in B
    const wordsA = normalizedA.split(' ').filter(w => w.length > 4);
    if (wordsA.length === 0) return true; // No significant words = consider subset
    const matchingWords = wordsA.filter(w => normalizedB.includes(w));
    return matchingWords.length >= wordsA.length * 0.8;
  }

  // Case 1: HTML is subset of text - text has additional content (reply case)
  if (isContentSubset(htmlContent, textContent)) {
    rawEmailText = textContent;
  }
  // Case 2: Text is subset of HTML - text is redundant (Google One case)
  else if (isContentSubset(textContent, htmlContent)) {
    rawEmailText = htmlContent;
  }
  // Case 3: Neither is subset - check for unique text content
  else {
    // Split into chunks and find truly unique content in text
    const textChunks = textContent
      .split(/[.!?\n]+/)
      .map(s => s.trim())
      .filter(s => s.length > 30);

    const uniqueChunks = textChunks.filter(chunk => {
      const words = normalize(chunk).split(' ').filter(w => w.length > 4);
      if (words.length === 0) return false;
      const matchingWords = words.filter(w => normalizedHtml.includes(w));
      // Chunk is unique if less than 50% of its words are in HTML
      return matchingWords.length < words.length * 0.5;
    });

    if (uniqueChunks.length >= 2) {
      // Text has significant unique content - merge with HTML first, text after
      rawEmailText = htmlContent + '\n\n---\n\n' + uniqueChunks.join(' ');
    } else {
      // Mostly overlap - use the longer one
      rawEmailText = htmlContent.length > textContent.length ? htmlContent : textContent;
    }
  }
}

// 3. Sanitize the extracted text
let body_sanitized = '';
if (rawEmailText.trim()) {
  body_sanitized = rawEmailText
    .normalize('NFD')
    .replace(/[\x00-\x1F\x7F-\x9F]/g, ' ')
    .replace(/[\u200B-\u200F\u2028-\u202F\u205F-\u206F\uFEFF\u034F\u00AD]/g, '')
    .replace(/[\u00A0\u1680\u2000-\u200A\u3000]/g, ' ')
    .replace(/https?:\/\/[^\s]*\.(jpg|jpeg|png|gif|svg|webp)[^\s]*/gi, '')
    .replace(/https?:\/\/[^\s]+/gi, '[link]')
    .replace(/\s+([.,;!?])/g, '$1')
    .replace(/\s+/g, ' ')
    .trim();
}

// 4. Build attachment texts MAP
const attachment_texts_map = {};
const gmailBinaryKeys = Object.keys($('Gmail').first().binary || {});
const hasAttachments = gmailBinaryKeys.length > 0;

for (let i = 0; i < items.length; i++) {
  const $json = items[i].json;
  const text = $json.data?.text || $json.textForLLM || $json.text || '';
  const key = gmailBinaryKeys[i] || `attachment_${i}`;
  if (text.trim()) {
    attachment_texts_map[key] = text.trim();
  }
}

// 5. Compute direction-based fields
const isOutbound = gmail.labelIds.includes('SENT');
const from = gmail.from.value[0];
const to = gmail.to.value[0];

// 6. Return ONE item
return [{
  json: {
    data: [{
      body_sanitized,
      attachment_texts_map,
      attachmentNames: gmailBinaryKeys,
      hasAttachments,
      subject: gmail.subject || 'No subject',
      from: gmail.from || 'Unknown',
      date: gmail.date || new Date().toISOString()
    }],
    direction: isOutbound ? 'outbound' : 'inbound',
    owner_email: isOutbound ? from.address : to.address,
    contact_email: isOutbound ? to.address : from.address,
    contact_name: isOutbound ? (to.name || '') : (from.name || '')
  },
  pairedItem: { item: 0 }
}];
