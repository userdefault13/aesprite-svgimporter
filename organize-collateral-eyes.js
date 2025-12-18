#!/usr/bin/env node

/**
 * Organize collateral-specific eyes into collateral-eyes-{collateral} folders
 * Moves only the Range 98-99 collateral-specific eye folders
 */

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const OUTPUT_DIR = '/Users/juliuswong/Dev/aesprite-svgimporter/output'

// Map of collateral names to their collateral-specific eye folder names
const COLLATERAL_EYE_FOLDERS = {
  'amaave': 'amAAVECollateral_Range_98-99',
  'amdai': 'amDAICollateral_Range_98-99',
  'amusdc': 'amUSDCCollateral_Range_98-99',
  'amusdt': 'amUSDTCollateral_Range_98-99',
  'amwbtc': 'amWBTCCollateral_Range_98-99',
  'amweth': 'amWETHCollateral_Range_98-99',
  'amwmatic': 'amWMATICCollateral_Range_98-99',
  'maaave': 'maAAVECollateral_Range_98-99',
  'madai': 'maDAICollateral_Range_98-99',
  'malink': 'maLINKCollateral_Range_98-99',
  'matusd': 'maTUSDCollateral_Range_98-99',
  'maUNI': 'maUNICollateral_Range_98-99',
  'mausdc': 'maUSDCCollateral_Range_98-99',
  'mausdt': 'maUSDTCollateral_Range_98-99',
  'maweth': 'maWETHCollateral_Range_98-99',
  'mayfi': 'maYFICollateral_Range_98-99'
}

function moveDirectory(src, dest) {
  // Create destination parent directory if it doesn't exist
  const destParent = path.dirname(dest)
  if (!fs.existsSync(destParent)) {
    fs.mkdirSync(destParent, { recursive: true })
  }
  
  // Move the directory
  fs.renameSync(src, dest)
  console.log(`  ✓ Moved: ${path.basename(src)}`)
}

function organizeCollateralEyes(collateralName) {
  const collateralDir = path.join(OUTPUT_DIR, collateralName)
  const eyesDir = path.join(collateralDir, 'Eyes')
  const collateralEyeFolderName = COLLATERAL_EYE_FOLDERS[collateralName]
  
  if (!collateralEyeFolderName) {
    console.log(`⚠ Skipping ${collateralName}: No collateral eye folder mapping found`)
    return false
  }
  
  if (!fs.existsSync(collateralDir)) {
    console.log(`⚠ Skipping ${collateralName}: Collateral directory not found`)
    return false
  }
  
  if (!fs.existsSync(eyesDir)) {
    console.log(`⚠ Skipping ${collateralName}: Eyes directory not found`)
    return false
  }
  
  const collateralEyeFolder = path.join(eyesDir, collateralEyeFolderName)
  
  if (!fs.existsSync(collateralEyeFolder)) {
    console.log(`⚠ Skipping ${collateralName}: Collateral eye folder not found: ${collateralEyeFolderName}`)
    return false
  }
  
  // Create the new collateral-eyes-{collateral} directory
  const newCollateralEyesDir = path.join(collateralDir, `collateral-eyes-${collateralName}`)
  
  // Move the collateral-specific eye folder
  const destFolder = path.join(newCollateralEyesDir, collateralEyeFolderName)
  
  console.log(`\nProcessing ${collateralName}:`)
  console.log(`  Source: ${collateralEyeFolder}`)
  console.log(`  Destination: ${destFolder}`)
  
  moveDirectory(collateralEyeFolder, destFolder)
  
  return true
}

function main() {
  console.log('Organizing Collateral-Specific Eyes')
  console.log('===================================\n')
  
  const collaterals = Object.keys(COLLATERAL_EYE_FOLDERS).sort()
  
  let successCount = 0
  let skipCount = 0
  
  for (const collateral of collaterals) {
    if (organizeCollateralEyes(collateral)) {
      successCount++
    } else {
      skipCount++
    }
  }
  
  console.log('\n===================================')
  console.log('SUMMARY')
  console.log('===================================')
  console.log(`Successfully organized: ${successCount}/${collaterals.length}`)
  console.log(`Skipped: ${skipCount}/${collaterals.length}`)
  console.log('===================================\n')
}

main()

