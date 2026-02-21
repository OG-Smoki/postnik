const { Resvg } = require('@resvg/resvg-js');
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const svgPath = path.join(__dirname, 'assets/images/icon_colored.svg');
const svg = fs.readFileSync(svgPath, 'utf-8');

// Render SVG to PNG at 1024x1024
const resvg = new Resvg(svg, { fitTo: { mode: 'width', value: 1024 } });
const pngData = resvg.render();
const pngBuffer = pngData.asPng();

// Save main icon.png
fs.writeFileSync(path.join(__dirname, 'assets/images/icon.png'), pngBuffer);
console.log('Generated assets/images/icon.png (1024x1024)');

// Android mipmap sizes
const androidSizes = [
  { name: 'mipmap-mdpi',    size: 48 },
  { name: 'mipmap-hdpi',    size: 72 },
  { name: 'mipmap-xhdpi',   size: 96 },
  { name: 'mipmap-xxhdpi',  size: 144 },
  { name: 'mipmap-xxxhdpi', size: 192 },
];

// iOS icon sizes
const iosSizes = [
  { name: 'Icon-App-20x20@1x',    size: 20 },
  { name: 'Icon-App-20x20@2x',    size: 40 },
  { name: 'Icon-App-20x20@3x',    size: 60 },
  { name: 'Icon-App-29x29@1x',    size: 29 },
  { name: 'Icon-App-29x29@2x',    size: 58 },
  { name: 'Icon-App-29x29@3x',    size: 87 },
  { name: 'Icon-App-40x40@1x',    size: 40 },
  { name: 'Icon-App-40x40@2x',    size: 80 },
  { name: 'Icon-App-40x40@3x',    size: 120 },
  { name: 'Icon-App-60x60@2x',    size: 120 },
  { name: 'Icon-App-60x60@3x',    size: 180 },
  { name: 'Icon-App-76x76@1x',    size: 76 },
  { name: 'Icon-App-76x76@2x',    size: 152 },
  { name: 'Icon-App-83.5x83.5@2x',size: 167 },
  { name: 'Icon-App-1024x1024@1x',size: 1024 },
];

async function generate() {
  // Android
  for (const { name, size } of androidSizes) {
    const dir = path.join(__dirname, 'android/app/src/main/res', name);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    await sharp(pngBuffer).resize(size, size).png().toFile(path.join(dir, 'ic_launcher.png'));
    console.log(`Android ${name}: ${size}x${size}`);
  }

  // iOS
  const iosDir = path.join(__dirname, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
  for (const { name, size } of iosSizes) {
    await sharp(pngBuffer).resize(size, size).png().toFile(path.join(iosDir, `${name}.png`));
    console.log(`iOS ${name}: ${size}x${size}`);
  }

  // Update iOS Contents.json
  const contentsJson = {
    images: iosSizes.map(({ name, size }) => {
      const parts = name.replace('Icon-App-', '').split('@');
      const scale = parts[1] || '1x';
      const dim = parts[0];
      return {
        filename: `${name}.png`,
        idiom: size >= 76 && size <= 167 ? 'ipad' : 'iphone',
        scale,
        size: dim,
      };
    }),
    info: { author: 'xcode', version: 1 }
  };

  // Add universal 1024 entry
  contentsJson.images.push({
    filename: 'Icon-App-1024x1024@1x.png',
    idiom: 'ios-marketing',
    scale: '1x',
    size: '1024x1024',
  });

  fs.writeFileSync(
    path.join(iosDir, 'Contents.json'),
    JSON.stringify(contentsJson, null, 2)
  );

  console.log('Done! All icons generated.');
}

generate().catch(console.error);
