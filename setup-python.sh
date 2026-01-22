#!/bin/bash
#
# setup-python.sh
# Sets up Python environment for Motion Hub preprocessing
#

set -e  # Exit on error

echo "🐍 Setting up Python environment for Motion Hub..."
echo ""

# Check Python version
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 not found. Please install Python 3.11 or later."
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo "✓ Found Python $PYTHON_VERSION"

# Navigate to preprocessing directory
cd "$(dirname "$0")/preprocessing"
echo "✓ In preprocessing directory"

# Create virtual environment
echo ""
echo "Creating virtual environment..."
python3 -m venv venv

echo "✓ Virtual environment created"

# Activate virtual environment
echo ""
echo "Activating virtual environment..."
source venv/bin/activate

echo "✓ Virtual environment activated"

# Upgrade pip
echo ""
echo "Upgrading pip..."
pip install --upgrade pip --quiet

echo "✓ pip upgraded"

# Install dependencies
echo ""
echo "Installing dependencies from requirements.txt..."
pip install -r requirements.txt

echo ""
echo "✓ All dependencies installed"

# Verify installations
echo ""
echo "Verifying installations..."
python3 -c "import numpy; print(f'  ✓ numpy {numpy.__version__}')"
python3 -c "import cv2; print(f'  ✓ opencv-python {cv2.__version__}')"
python3 -c "import sklearn; print(f'  ✓ scikit-learn {sklearn.__version__}')"
python3 -c "import PIL; print(f'  ✓ Pillow {PIL.__version__}')"
python3 -c "import ffmpeg; print('  ✓ ffmpeg-python installed')"

echo ""
echo "✅ Python environment setup complete!"
echo ""
echo "To activate the environment in the future, run:"
echo "  cd preprocessing"
echo "  source venv/bin/activate"
echo ""
echo "To test the extraction script, run:"
echo "  python extract.py --help"
echo ""
