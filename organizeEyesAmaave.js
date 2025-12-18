#!/usr/bin/env node

/**
 * Copy Eyes folder for amaave from AavegotchiQuerey to output directory
 */

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const sourceDir = '/Users/juliuswong/Dev/AavegotchiQuerey/cli/exports/SVGs/Eyes/amaave'
const targetDir = '/Users/juliuswong/Dev/aesprite-svgimporter/output/amaave/Eyes'

// Recursive copy function
function copyRecursive(src, dest) {
  if (!fs.existsSync(src)) {
    throw new Error(`Source does not exist: ${src}`)
  }

  const stat = fs.statSync(src)

  if (stat.isDirectory()) {
    // Create destination directory if it doesn't exist
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true })
    }

    // Copy all items in the directory
    const items = fs.readdirSync(src)
    for (const item of items) {
      copyRecursive(
        path.join(src, item),
        path.join(dest, item)
      )
    }
  } else {
    // Copy file
    fs.copyFileSync(src, dest)
  }
}

// Main execution
try {
  console.log('Copying Eyes folder for amaave...')
  console.log(`  From: ${sourceDir}`)
  console.log(`  To: ${targetDir}`)

  // Check if source exists
  if (!fs.existsSync(sourceDir)) {
    throw new Error(`Source directory not found: ${sourceDir}`)
  }

  // Create target directory
  const targetParent = path.dirname(targetDir)
  if (!fs.existsSync(targetParent)) {
    throw new Error(`Target parent directory not found: ${targetParent}`)
  }

  // Copy the entire structure
  copyRecursive(sourceDir, targetDir)

  console.log('✓ Successfully copied Eyes folder structure')
  console.log(`\nStructure in ${targetDir}:`)
  
  // List top-level directories
  const items = fs.readdirSync(targetDir)
  for (const item of items) {
    const itemPath = path.join(targetDir, item)
    if (fs.statSync(itemPath).isDirectory()) {
      // Count JSON files recursively
      let jsonCount = 0
      function countJson(dir) {
        const entries = fs.readdirSync(dir)
        for (const entry of entries) {
          const entryPath = path.join(dir, entry)
          if (fs.statSync(entryPath).isDirectory()) {
            countJson(entryPath)
          } else if (entry.endsWith('.json')) {
            jsonCount++
          }
        }
      }
      countJson(itemPath)
      console.log(`  ${item}/ (${jsonCount} JSON files)`)
    }
  }
} catch (error) {
  console.error(`✗ Error: ${error.message}`)
  process.exit(1)
}

