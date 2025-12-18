import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import { execSync } from 'child_process'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

/**
 * Convert hands SVGs to Aseprite files
 */
function main() {
  const args = process.argv.slice(2)
  const handsDir = args[0] || path.join(__dirname, '../Aseprite-AavegotchiPaaint/Output/hands')
  const outputDir = args[1] || path.join(__dirname, '../Aseprite-AavegotchiPaaint/Output')
  const svgImporterPath = path.join(__dirname, 'svg-importer-cli.lua')
  const tempDir = path.join(__dirname, 'tmp-hands')
  
  console.log('=== Convert Hands SVGs to Aseprite ===')
  console.log(`Hands directory: ${handsDir}`)
  console.log(`Output directory: ${outputDir}`)
  console.log(`SVG importer: ${svgImporterPath}\n`)
  
  if (!fs.existsSync(handsDir)) {
    console.error(`Error: Hands directory does not exist: ${handsDir}`)
    process.exit(1)
  }
  
  // Find aseprite executable
  let asepriteCmd = ''
  try {
    execSync('which aseprite', { stdio: 'ignore' })
    asepriteCmd = 'aseprite'
  } catch (error) {
    // Try macOS app bundle location
    const macAsepritePath = '/Applications/Aseprite.app/Contents/MacOS/aseprite'
    if (fs.existsSync(macAsepritePath)) {
      asepriteCmd = macAsepritePath
    } else {
      console.error('Error: aseprite command not found. Please install Aseprite and ensure it\'s in your PATH or at /Applications/Aseprite.app')
      process.exit(1)
    }
  }
  
  // Check if SVG importer script exists
  if (!fs.existsSync(svgImporterPath)) {
    console.error(`Error: SVG importer script not found: ${svgImporterPath}`)
    process.exit(1)
  }
  
  // Create temp directory for SVG files
  if (!fs.existsSync(tempDir)) {
    fs.mkdirSync(tempDir, { recursive: true })
  }
  
  // Create output directory
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true })
  }
  
  // Read all hands JSON files
  const handsFiles = fs.readdirSync(handsDir)
    .filter(f => f.startsWith('hands-') && f.endsWith('.json'))
    .map(f => path.join(handsDir, f))
  
  console.log(`Found ${handsFiles.length} hands files\n`)
  
  let successCount = 0
  let errorCount = 0
  
  for (const handsFilePath of handsFiles) {
    try {
      const handsData = JSON.parse(fs.readFileSync(handsFilePath, 'utf8'))
      const { name, hands } = handsData
      
      if (!hands || !hands.left || !hands.right) {
        console.log(`  ⚠ Skipping ${name}: missing left or right hands`)
        continue
      }
      
      console.log(`Processing ${name}...`)
      
      // Process left hand
      if (hands.left) {
        const leftSvgPath = path.join(tempDir, `hands_left_${name.toLowerCase()}.svg`)
        const leftAsePath = path.join(outputDir, `hands_left_${name.toLowerCase()}.aseprite`)
        
        // Write SVG to temp file
        fs.writeFileSync(leftSvgPath, hands.left, 'utf8')
        
        // Convert to aseprite
        // Run from current directory (aesprite-svgimporter) so it can find the Lua modules
        // Use environment variables to pass arguments
        const scriptName = path.basename(svgImporterPath)
        
        try {
          execSync(
            `cd "${__dirname}" && SVG_FILE="${leftSvgPath}" SVG_WIDTH="64" SVG_HEIGHT="64" SVG_OUTPUT="${leftAsePath}" "${asepriteCmd}" -b --script "${scriptName}"`,
            { stdio: 'inherit', env: { ...process.env, SVG_FILE: leftSvgPath, SVG_WIDTH: '64', SVG_HEIGHT: '64', SVG_OUTPUT: leftAsePath } }
          )
          console.log(`  ✓ Left hand: ${path.basename(leftAsePath)}`)
          successCount++
        } catch (error) {
          console.error(`  ✗ Error converting left hand: ${error.message}`)
          errorCount++
        }
        
        // Clean up temp SVG
        if (fs.existsSync(leftSvgPath)) {
          fs.unlinkSync(leftSvgPath)
        }
      }
      
      // Process right hand
      if (hands.right) {
        const rightSvgPath = path.join(tempDir, `hands_right_${name.toLowerCase()}.svg`)
        const rightAsePath = path.join(outputDir, `hands_right_${name.toLowerCase()}.aseprite`)
        
        // Write SVG to temp file
        fs.writeFileSync(rightSvgPath, hands.right, 'utf8')
        
        // Convert to aseprite
        // Run from current directory (aesprite-svgimporter) so it can find the Lua modules
        // Use environment variables to pass arguments
        const scriptName = path.basename(svgImporterPath)
        
        try {
          execSync(
            `cd "${__dirname}" && SVG_FILE="${rightSvgPath}" SVG_WIDTH="64" SVG_HEIGHT="64" SVG_OUTPUT="${rightAsePath}" "${asepriteCmd}" -b --script "${scriptName}"`,
            { stdio: 'inherit', env: { ...process.env, SVG_FILE: rightSvgPath, SVG_WIDTH: '64', SVG_HEIGHT: '64', SVG_OUTPUT: rightAsePath } }
          )
          console.log(`  ✓ Right hand: ${path.basename(rightAsePath)}`)
          successCount++
        } catch (error) {
          console.error(`  ✗ Error converting right hand: ${error.message}`)
          errorCount++
        }
        
        // Clean up temp SVG
        if (fs.existsSync(rightSvgPath)) {
          fs.unlinkSync(rightSvgPath)
        }
      }
      
    } catch (error) {
      console.error(`  ✗ Error processing ${path.basename(handsFilePath)}:`, error.message)
      errorCount++
    }
  }
  
  // Clean up temp directory
  try {
    if (fs.existsSync(tempDir)) {
      const tempFiles = fs.readdirSync(tempDir)
      if (tempFiles.length === 0) {
        fs.rmdirSync(tempDir)
      }
    }
  } catch (error) {
    // Ignore cleanup errors
  }
  
  console.log('\n=== Summary ===')
  console.log(`Total files processed: ${handsFiles.length}`)
  console.log(`Success: ${successCount}`)
  console.log(`Errors: ${errorCount}`)
  console.log(`\n✓ Output directory: ${outputDir}`)
}

main()

