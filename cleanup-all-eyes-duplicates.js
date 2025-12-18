#!/usr/bin/env node

/**
 * Clean up duplicate eye JSON files in all nested folders for a specific collateral
 * Cleans up duplicates in all rarity folders (Collateral, Common, MythicalLow, etc.)
 */

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// Get collateral name from command line argument
const collateralName = process.argv[2] || 'amaave'
const baseDir = `/Users/juliuswong/Dev/AavegotchiQuerey/cli/exports/SVGs/Eyes/${collateralName}`

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

// Main execution
try {
  console.log(`Cleaning up duplicates for collateral: ${collateralName}`)
  console.log(`Base directory: ${baseDir}\n`)
  
  if (!fs.existsSync(baseDir)) {
    console.error(`ERROR: Directory not found: ${baseDir}`)
    process.exit(1)
  }
  
  const folders = findFoldersWithJsonFiles(baseDir)
  
  if (folders.length === 0) {
    console.log('No folders with JSON files found!')
    process.exit(1)
  }
  
  console.log(`Found ${folders.length} folders with JSON files\n`)
  console.log(`${'='.repeat(60)}\n`)
  
  let totalKept = 0
  let totalDeleted = 0
  let processedCount = 0
  let cleanedFolders = 0
  
  for (const folder of folders) {
    const relativePath = path.relative(baseDir, folder)
    const folderName = relativePath || path.basename(folder)
    
    try {
      const { keptCount, deletedCount, hadDuplicates } = cleanupDuplicates(folder)
      
      if (deletedCount > 0) {
        console.log(`[${processedCount + 1}/${folders.length}] ${folderName}`)
        console.log(`  ✓ Kept: ${keptCount} files, Deleted: ${deletedCount} duplicates`)
        totalKept += keptCount
        totalDeleted += deletedCount
        cleanedFolders++
      } else if (hadDuplicates === false && keptCount > 0) {
        // Folder was already clean
        totalKept += keptCount
      }
      
      processedCount++
    } catch (error) {
      console.error(`  ✗ Error processing ${folderName}: ${error.message}`)
    }
  }
  
  console.log(`\n${'='.repeat(60)}`)
  console.log(`CLEANUP COMPLETE`)
  console.log(`${'='.repeat(60)}`)
  console.log(`Collateral: ${collateralName}`)
  console.log(`Folders processed: ${processedCount}`)
  console.log(`Folders cleaned: ${cleanedFolders}`)
  console.log(`Total files kept: ${totalKept}`)
  console.log(`Total files deleted: ${totalDeleted}`)
  console.log(`${'='.repeat(60)}\n`)
  
} catch (error) {
  console.error(`✗ Error: ${error.message}`)
  console.error(error.stack)
  process.exit(1)
}

