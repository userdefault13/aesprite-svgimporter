#!/usr/bin/env node

/**
 * Clean up duplicate eye JSON files in all collateral folders
 * Finds all Collateral_Range_98-99 folders and cleans them up
 */

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import { execSync } from 'child_process'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const baseDir = '/Users/juliuswong/Dev/AavegotchiQuerey/cli/exports/SVGs/Eyes'
const cleanupScript = path.join(__dirname, 'cleanup-duplicate-eyes.js')

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

function findCollateralFolders(baseDir) {
  const folders = []
  
  function walkDir(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true })
    
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name)
      
      if (entry.isDirectory()) {
        if (entry.name.includes('Collateral_Range_98-99')) {
          folders.push(fullPath)
        } else {
          walkDir(fullPath)
        }
      }
    }
  }
  
  if (fs.existsSync(baseDir)) {
    walkDir(baseDir)
  }
  
  return folders.sort()
}

function cleanupDuplicates(dir) {
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.json'))
  
  // Group files by eye color type
  const filesByType = {}
  
  for (const file of files) {
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

  let deletedCount = 0
  let keptCount = 0
  
  for (const colorType of eyeColorTypes) {
    const files = filesByType[colorType] || []
    
    if (files.length === 0) {
      continue
    }
    
    if (files.length === 1) {
      keptCount++
      continue
    }
    
    // Sort by timestamp (newest first)
    files.sort((a, b) => b.timestamp - a.timestamp)
    
    const keepFile = files[0]
    const deleteFiles = files.slice(1)
    
    keptCount++
    
    // Delete older files
    for (const file of deleteFiles) {
      const filePath = path.join(dir, file.filename)
      fs.unlinkSync(filePath)
      deletedCount++
    }
  }
  
  return { keptCount, deletedCount }
}

// Main execution
try {
  console.log('Finding all collateral folders...\n')
  
  const collateralFolders = findCollateralFolders(baseDir)
  
  if (collateralFolders.length === 0) {
    console.log('No collateral folders found!')
    process.exit(1)
  }
  
  console.log(`Found ${collateralFolders.length} collateral folders to clean up:\n`)
  for (const folder of collateralFolders) {
    const relativePath = path.relative(baseDir, folder)
    console.log(`  - ${relativePath}`)
  }
  
  console.log(`\n${'='.repeat(60)}\n`)
  
  let totalKept = 0
  let totalDeleted = 0
  let processedCount = 0
  
  for (const folder of collateralFolders) {
    const relativePath = path.relative(baseDir, folder)
    const folderName = path.basename(folder)
    
    console.log(`\n[${processedCount + 1}/${collateralFolders.length}] Processing: ${relativePath}`)
    
    try {
      const { keptCount, deletedCount } = cleanupDuplicates(folder)
      
      if (deletedCount > 0) {
        console.log(`  ✓ Kept: ${keptCount} files, Deleted: ${deletedCount} duplicates`)
        totalKept += keptCount
        totalDeleted += deletedCount
      } else {
        console.log(`  ✓ Already clean (${keptCount} files)`)
        totalKept += keptCount
      }
      
      processedCount++
    } catch (error) {
      console.error(`  ✗ Error: ${error.message}`)
    }
  }
  
  console.log(`\n${'='.repeat(60)}`)
  console.log(`BATCH CLEANUP COMPLETE`)
  console.log(`${'='.repeat(60)}`)
  console.log(`Processed folders: ${processedCount}/${collateralFolders.length}`)
  console.log(`Total files kept: ${totalKept}`)
  console.log(`Total files deleted: ${totalDeleted}`)
  console.log(`${'='.repeat(60)}\n`)
  
} catch (error) {
  console.error(`✗ Error: ${error.message}`)
  process.exit(1)
}

