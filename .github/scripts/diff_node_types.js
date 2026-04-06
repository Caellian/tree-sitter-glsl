#!/usr/bin/env node
/**
 * Diffs two node-types.json files and produces human-readable AST change notes.
 *
 * Usage: diff_node_types.js <old.json> <new.json>
 *   Reads from files or stdin with "-" for new.
 *   Outputs markdown to stdout.
 */

import {readFileSync} from 'node:fs';

const [,, oldPath, newPath] = process.argv;
if (!oldPath || !newPath) {
  console.error('Usage: diff_node_types.js <old.json> <new.json>');
  process.exit(1);
}

const oldTypes = JSON.parse(readFileSync(oldPath, 'utf8'));
const newTypes = JSON.parse(readFileSync(newPath, 'utf8'));

/** @param {object[]} types */
function index(types) {
  const map = new Map();
  for (const t of types) {
    if (t.named) map.set(t.type, t);
  }
  return map;
}

const oldMap = index(oldTypes);
const newMap = index(newTypes);

// Bucketed by priority
const removals = [];
const additions = [];
const renameLines = [];
const fieldRemovals = [];
const fieldAdditions = [];
const otherChanges = [];

// Added/removed nodes
const addedNodes = [...newMap.keys()].filter(k => !oldMap.has(k));
const removedNodes = [...oldMap.keys()].filter(k => !newMap.has(k));

// Detect renames: removed node whose fields/subtypes match an added node
const renames = [];
for (const r of removedNodes) {
  const oldNode = oldMap.get(r);
  const oldSig = nodeSignature(oldNode);
  for (const a of addedNodes) {
    const newNode = newMap.get(a);
    if (nodeSignature(newNode) === oldSig) {
      renames.push({from: r, to: a});
      break;
    }
  }
}
const renamedFrom = new Set(renames.map(r => r.from));
const renamedTo = new Set(renames.map(r => r.to));

for (const name of removedNodes) {
  if (!renamedFrom.has(name)) {
    removals.push(`- \`${name}\` was removed.`);
  }
}

for (const name of addedNodes) {
  if (!renamedTo.has(name)) {
    additions.push(`- \`${name}\` was added.`);
  }
}

for (const {from, to} of renames) {
  renameLines.push(`- \`${from}\` was renamed to \`${to}\`.`);
}

// Changed nodes
for (const [name, newNode] of newMap) {
  if (!oldMap.has(name) || renamedTo.has(name)) continue;
  const oldNode = oldMap.get(name);

  // Subtype changes
  const oldSubs = (oldNode.subtypes || []).map(s => s.type).sort();
  const newSubs = (newNode.subtypes || []).map(s => s.type).sort();
  for (const s of newSubs) {
    if (!oldSubs.includes(s)) {
      otherChanges.push(`- \`${s}\` was added as a subtype of \`${name}\`.`);
    }
  }
  for (const s of oldSubs) {
    if (!newSubs.includes(s)) {
      otherChanges.push(`- \`${s}\` was removed as a subtype of \`${name}\`.`);
    }
  }

  // Field changes
  const oldFields = Object.keys(oldNode.fields || {}).sort();
  const newFields = Object.keys(newNode.fields || {}).sort();
  for (const f of oldFields) {
    if (!newFields.includes(f)) {
      fieldRemovals.push(`- field \`${f}\` was removed from \`${name}\`.`);
    }
  }
  for (const f of newFields) {
    if (!oldFields.includes(f)) {
      const types = (newNode.fields[f].types || [])
        .filter(t => t.named)
        .map(t => `\`${t.type}\``);
      const detail = types.length
        ? `, accepting ${types.length === 1 ? types[0] : types.slice(0, -1).join(', ') + ' and ' + types.at(-1)}`
        : '';
      fieldAdditions.push(`- field \`${f}\` was added to \`${name}\`${detail}.`);
    }
  }

  // Field type changes
  for (const f of newFields) {
    if (!oldFields.includes(f)) continue;
    const oldFTypes = (oldNode.fields[f].types || []).map(t => t.type).sort();
    const newFTypes = (newNode.fields[f].types || []).map(t => t.type).sort();
    const added = newFTypes.filter(t => !oldFTypes.includes(t));
    const removed = oldFTypes.filter(t => !newFTypes.includes(t));
    for (const t of added) {
      otherChanges.push(`- \`${name}\`.${f} now accepts \`${t}\`.`);
    }
    for (const t of removed) {
      otherChanges.push(`- \`${name}\`.${f} no longer accepts \`${t}\`.`);
    }
  }

  // Children changes (non-field)
  const oldChildren = (oldNode.children?.types || []).map(t => t.type).sort();
  const newChildren = (newNode.children?.types || []).map(t => t.type).sort();
  for (const c of newChildren) {
    if (!oldChildren.includes(c)) {
      otherChanges.push(`- \`${c}\` was added as a child of \`${name}\`.`);
    }
  }
  for (const c of oldChildren) {
    if (!newChildren.includes(c)) {
      otherChanges.push(`- \`${c}\` was removed as a child of \`${name}\`.`);
    }
  }
}

// Output in priority order
const lines = [
  ...removals,
  ...additions,
  ...renameLines,
  ...fieldRemovals,
  ...fieldAdditions,
  ...otherChanges,
];

const MAX_LINES = 30;
if (lines.length > 0) {
  if (lines.length > MAX_LINES) {
    const rest = lines.length - MAX_LINES;
    console.log(lines.slice(0, MAX_LINES).join('\n'));
    console.log(`- ...and ${rest} other change${rest > 1 ? 's' : ''}.`);
  } else {
    console.log(lines.join('\n'));
  }
}

/** Produce a structural signature for rename detection. */
function nodeSignature(node) {
  const parts = [];
  if (node.subtypes) {
    parts.push('sub:' + node.subtypes.map(s => s.type).sort().join(','));
  }
  if (node.fields) {
    parts.push('fields:' + Object.keys(node.fields).sort().join(','));
  }
  if (node.children) {
    parts.push('children:' + node.children.types.map(t => t.type).sort().join(','));
  }
  return parts.join('|');
}
