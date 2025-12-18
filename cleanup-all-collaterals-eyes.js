#!/usr/bin/env node

/**
 * Batch cleanup duplicate eye JSON files for all collaterals
 * Processes all 16 collaterals
 */

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const baseEyesDir = '/Users/juliuswong/Dev/AavegotchiQuerey/cli/exports/SVGs/Eyes'
const cleanupScript = path.join(__dirname, 'cleanup-all-eyes-duplicates.js')

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
  if (!fs.existsSync(dir)) {
    return { keptCount: 0, deletedCount: 0, hadDuplicates: false }
  }
  
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.json'))
  
  if (files.length === 0) {
    return { keptCount: 0, deletedCount: 0, hadDuplicates: false }
  }
  
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
  let hadDuplicates = false
  
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
    hadDuplicates = true
    
    // Delete older files
    for (const file of deleteFiles) {
      const filePath = path.join(dir, file.filename)
      fs.unlinkSync(filePath)
      deletedCount++
    }
  }
  
  // Handle any files that don't match the expected pattern
  const allFiles = fs.readdirSync(dir).filter(f => f.endsWith('.json'))
  const processedFiles = Object.values(filesByType).flat().map(f => f.filename)
  const unexpectedFiles = allFiles.filter(f => !processedFiles.includes(f))
  
  keptCount += unexpectedFiles.length
  
  return { keptCount, deletedCount, hadDuplicates }
}

function findFoldersWithJsonFiles(baseDir) {
  const folders = []
  
  function walkDir(dir) {
    if (!fs.existsSync(dir)) {
      return
    }
    
    const entries = fs.readdirSync(dir, { withFileTypes: true })
    let hasJsonFiles = false
    
    for (const entry of entries) {
      if (entry.isFile() && entry.name.endsWith('.json')) {
        hasJsonFiles = true
        break
      }
    }
    
    if (hasJsonFiles) {
      folders.push(dir)
      return // Don't go deeper if this folder has JSON files
    }
    
    // Continue walking subdirectories
    for (const entry of entries) {
      if (entry.isDirectory()) {
        walkDir(path.join(dir, entry.name))
      }
    }
  }
  
  walkDir(baseDir)
  return folders.sort()
}

function getAllCollaterals() {
  if (!fs.existsSync(baseEyesDir)) {
    return []
  }
  
  const entries = fs.readdirSync(baseEyesDir, { withFileTypes: true })
  return entries
    .filter(entry => entry.isDirectory())
    .map(entry => entry.name)
    .sort()
}

// Main execution
try {
  console.log('Batch cleanup for all collaterals')
  console.log(`${'='.repeat(60)}\n`)
  
  const allCollaterals = getAllCollaterals()
  
  if (allCollaterals.length === 0) {
    console.log('No collaterals found!')
    process.exit(1)
  }
  
  console.log(`Found ${allCollaterals.length} collaterals to process:\n`)
  for (const collateral of allCollaterals) {
    console.log(`  - ${collateral}`)
  }
  
  console.log(`\n${'='.repeat(60)}\n`)
  
  let grandTotalKept = 0
  let grandTotalDeleted = 0
  let totalFoldersProcessed = 0
  let totalFoldersCleaned = 0
  
  for (let i = 0; i < allCollaterals.length; i++) {
    const collateral = allCollaterals[i]
    const collateralDir = path.join(baseEyesDir, collateral)
    
    console.log(`\n[${i + 1}/${allCollaterals.length}] Processing: ${collateral}`)
    console.log(`  Directory: ${collateralDir}`)
    
    if (!fs.existsSync(collateralDir)) {
      console.log(`  ⚠️  Directory not found, skipping`)
      continue
    }
    
    const folders = findFoldersWithJsonFiles(collateralDir)
    
    if (folders.length === 0) {
      console.log(`  ⚠️  No folders with JSON files found`)
      continue
    }
    
    console.log(`  Found ${folders.length} folders with JSON files`)
    
    let collateralKept = 0
    let collateralDeleted = 0
    let collateralCleaned = 0
    
    for (const folder of folders) {
      const relativePath = path.relative(collateralDir, folder)
      const folderName = relativePath || path.basename(folder)
      
      try {
        const { keptCount, deletedCount, hadDuplicates } = cleanupDuplicates(folder)
        
        if (deletedCount > 0) {
          collateralKept += keptCount
          collateralDeleted += deletedCount
          collateralCleaned++
          totalFoldersCleaned++
        } else if (hadDuplicates === false && keptCount > 0) {
          collateralKept += keptCount
        }
        
        totalFoldersProcessed++
      } catch (error) {
        console.error(`    ✗ Error processing ${folderName}: ${error.message}`)
      }
    }
    
    if (collateralDeleted > 0) {
      console.log(`  ✓ Cleaned ${collateralCleaned} folders`)
      console.log(`    Kept: ${collateralKept} files, Deleted: ${collateralDeleted} duplicates`)
    } else {
      console.log(`  ✓ Already clean (${collateralKept} files in ${folders.length} folders)`)
    }
    
    grandTotalKept += collateralKept
    grandTotalDeleted += collateralDeleted
  }
  
  console.log(`\n${'='.repeat(60)}`)
  console.log(`BATCH CLEANUP COMPLETE`)
  console.log(`${'='.repeat(60)}`)
  console.log(`Collaterals processed: ${allCollaterals.length}`)
  console.log(`Total folders processed: ${totalFoldersProcessed}`)
  console.log(`Total folders cleaned: ${totalFoldersCleaned}`)
  console.log(`Total files kept: ${grandTotalKept}`)
  console.log(`Total files deleted: ${grandTotalDeleted}`)
  console.log(`${'='.repeat(60)}\n`)
  
} catch (error) {
  console.error(`✗ Error: ${error.message}`)
  console.error(error.stack)
  process.exit(1)
}

