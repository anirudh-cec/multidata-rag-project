#!/bin/bash
set -e

# Build Tesseract Lambda Layer
# This script builds tesseract in an Amazon Linux 2023 container
# and packages it as a Lambda layer

echo "Building Tesseract Lambda Layer..."

# Create layer directory
LAYER_DIR="lambda-layer-tesseract"
rm -rf $LAYER_DIR
mkdir -p $LAYER_DIR

# Build tesseract in Amazon Linux 2023 container
docker run --rm -v $(pwd)/$LAYER_DIR:/output amazonlinux:2023 bash -c "
set -e

# Install dependencies
dnf install -y \
    gcc \
    gcc-c++ \
    make \
    autoconf \
    automake \
    libtool \
    pkgconfig \
    wget \
    tar \
    gzip \
    zlib-devel \
    libpng-devel \
    libjpeg-devel \
    libtiff-devel

# Build leptonica (tesseract dependency)
cd /tmp
wget http://www.leptonica.org/source/leptonica-1.83.1.tar.gz
tar -xzf leptonica-1.83.1.tar.gz
cd leptonica-1.83.1
./configure --prefix=/opt/tesseract
make -j\$(nproc)
make install

# Build tesseract
cd /tmp
wget https://github.com/tesseract-ocr/tesseract/archive/refs/tags/5.3.3.tar.gz
tar -xzf 5.3.3.tar.gz
cd tesseract-5.3.3
./autogen.sh
PKG_CONFIG_PATH=/opt/tesseract/lib/pkgconfig ./configure --prefix=/opt/tesseract
make -j\$(nproc)
make install

# Download English language data
mkdir -p /opt/tesseract/share/tessdata
cd /opt/tesseract/share/tessdata
wget https://github.com/tesseract-ocr/tessdata/raw/main/eng.traineddata

# Optional: Add more languages
# wget https://github.com/tesseract-ocr/tessdata/raw/main/fra.traineddata
# wget https://github.com/tesseract-ocr/tessdata/raw/main/spa.traineddata

# Copy to output (Lambda expects /opt prefix)
cp -r /opt/tesseract /output/
"

echo "Packaging layer..."
cd $LAYER_DIR
zip -r ../tesseract-layer.zip .
cd ..

echo ""
echo "✅ Layer built successfully: tesseract-layer.zip"
echo ""
echo "To publish to AWS Lambda:"
echo ""
echo "aws lambda publish-layer-version \\"
echo "    --layer-name tesseract \\"
echo "    --description 'Tesseract OCR 5.3.3 for Lambda' \\"
echo "    --zip-file fileb://tesseract-layer.zip \\"
echo "    --compatible-runtimes python3.12 \\"
echo "    --compatible-architectures arm64"
echo ""
echo "Then add the layer ARN to your Lambda function."
