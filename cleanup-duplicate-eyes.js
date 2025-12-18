#!/usr/bin/env node

/**
 * Clean up duplicate eye JSON files - keep only the most recent version of each eye color
 */

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// Get target directory from command line argument or use default
const targetDir = process.argv[2] || '/Users/juliuswong/Dev/AavegotchiQuerey/cli/exports/SVGs/Eyes/amaave/Collateral/amAAVECollateral_Range_98-99'

// Expected eye color types
const eyeColorTypes = [
  'common',
  'mythicalhigh',
  'mythicallow',
  'rarehigh',
  'rarelow',
  'uncommonhigh',
  'uncommonlow'
]

function cleanupDuplicates(dir) {
  console.log(`Cleaning up duplicates in: ${dir}\n`)

  if (!fs.existsSync(dir)) {
    console.error(`ERROR: Directory not found: ${dir}`)
    process.exit(1)
  }

  const files = fs.readdirSync(dir).filter(f => f.endsWith('.json'))
  
  // Group files by eye color type
  const filesByType = {}
  
  for (const file of files) {
    // Parse filename: eyes-{color}-{timestamp}.json
    const match = file.match(/^eyes-([^-]+)-(\d+)\.json$/)
    if (match) {
      const colorType = match[1]
      const timestamp = parseInt(match[2])
      
      if (!filesByType[colorType]) {
        filesByType[colorType] = []
      }
      
      filesByType[colorType].push({
        filename: file,
        timestamp: timestamp
      })
    }
  }

  // Find the most recent file for each type and delete others
  let deletedCount = 0
  let keptCount = 0
  
  for (const colorType of eyeColorTypes) {
    const files = filesByType[colorType] || []
    
    if (files.length === 0) {
      console.log(`⚠️  ${colorType}: No files found`)
      continue
    }
    
    if (files.length === 1) {
      console.log(`✓ ${colorType}: Only one file, keeping: ${files[0].filename}`)
      keptCount++
      continue
    }
    
    // Sort by timestamp (newest first)
    files.sort((a, b) => b.timestamp - a.timestamp)
    
    const keepFile = files[0]
    const deleteFiles = files.slice(1)
    
    console.log(`\n${colorType}:`)
    console.log(`  ✓ Keeping (newest): ${keepFile.filename}`)
    keptCount++
    
    // Delete older files
    for (const file of deleteFiles) {
      const filePath = path.join(dir, file.filename)
      fs.unlinkSync(filePath)
      console.log(`  ✗ Deleted: ${file.filename}`)
      deletedCount++
    }
  }
  
  // Check for any unexpected files
  const remainingFiles = fs.readdirSync(dir).filter(f => f.endsWith('.json'))
  const unexpectedFiles = remainingFiles.filter(f => {
    const match = f.match(/^eyes-([^-]+)-\d+\.json$/)
    return !match || !eyeColorTypes.includes(match[1])
  })
  
  if (unexpectedFiles.length > 0) {
    console.log(`\n⚠️  Unexpected files (not deleted):`)
    for (const file of unexpectedFiles) {
      console.log(`  ${file}`)
    }
  }
  
  console.log(`\n========================================`)
  console.log(`Summary:`)
  console.log(`  Files kept: ${keptCount}`)
  console.log(`  Files deleted: ${deletedCount}`)
  console.log(`  Remaining files: ${remainingFiles.length}`)
  console.log(`========================================`)
}

// Run cleanup
cleanupDuplicates(targetDir)

