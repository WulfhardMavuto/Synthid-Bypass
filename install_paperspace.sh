#!/bin/bash
# SynthID-Bypass Installation Script for Paperspace/Cloud Environments
# This script sets up ComfyUI with all required custom nodes and models
# for running the SynthID bypass workflows.
#
# Usage: 
#   chmod +x install_paperspace.sh
#   ./install_paperspace.sh
#
# Note: This script assumes you have a GPU instance with Python 3.10+ and CUDA installed

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SynthID-Bypass Installation for Paperspace${NC}"
echo -e "${GREEN}========================================${NC}"

# Configuration - modify these paths if needed
COMFYUI_DIR="${HOME}/ComfyUI"
WORKFLOWS_REPO="https://github.com/WulfhardMavuto/Synthid-Bypass.git"
WORKFLOWS_DIR="${HOME}/Synthid-Bypass"

# Function to print status messages
print_status() {
    echo -e "${GREEN}[*]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if CUDA is available
check_cuda() {
    print_status "Checking CUDA availability..."
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
        echo ""
    else
        print_warning "nvidia-smi not found. Make sure you're running on a GPU instance."
    fi
}

# Install system dependencies
install_system_deps() {
    print_status "Installing system dependencies..."
    if ! sudo apt-get update -qq; then
        print_error "Failed to update package lists. Check your network connection."
        exit 1
    fi
    if ! sudo apt-get install -y -qq git wget curl libgl1-mesa-glx libglib2.0-0; then
        print_error "Failed to install system dependencies. Check your permissions and network."
        exit 1
    fi
    print_status "System dependencies installed."
}

# Clone and setup ComfyUI
setup_comfyui() {
    print_status "Setting up ComfyUI..."
    
    if [ -d "$COMFYUI_DIR" ]; then
        print_warning "ComfyUI directory already exists. Updating..."
        cd "$COMFYUI_DIR"
        git pull --quiet
    else
        print_status "Cloning ComfyUI..."
        git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
        cd "$COMFYUI_DIR"
    fi
    
    print_status "Installing ComfyUI dependencies..."
    pip install -q -r requirements.txt
    
    print_status "ComfyUI setup complete."
}

# Install ComfyUI Manager
install_comfyui_manager() {
    print_status "Installing ComfyUI Manager..."
    
    CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
    mkdir -p "$CUSTOM_NODES_DIR"
    
    if [ -d "$CUSTOM_NODES_DIR/ComfyUI-Manager" ]; then
        print_warning "ComfyUI Manager already installed. Updating..."
        cd "$CUSTOM_NODES_DIR/ComfyUI-Manager"
        git pull --quiet
    else
        cd "$CUSTOM_NODES_DIR"
        git clone https://github.com/ltdrdata/ComfyUI-Manager.git
    fi
    
    print_status "ComfyUI Manager installed."
}

# Install required custom nodes
install_custom_nodes() {
    print_status "Installing required custom nodes..."
    
    CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
    cd "$CUSTOM_NODES_DIR"
    
    # List of required custom nodes
    declare -A CUSTOM_NODES
    CUSTOM_NODES["ComfyUI-Impact-Pack"]="https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    CUSTOM_NODES["ComfyUI-DyPE"]="https://github.com/wildminder/ComfyUI-DyPE.git"
    CUSTOM_NODES["rgthree-comfy"]="https://github.com/rgthree/rgthree-comfy.git"
    CUSTOM_NODES["masquerade-nodes-comfyui"]="https://github.com/BadCafeCode/masquerade-nodes-comfyui.git"
    CUSTOM_NODES["ComfyUI-Inpaint-CropAndStitch"]="https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git"
    CUSTOM_NODES["ComfyUI-SeedVR2_VideoUpscaler"]="https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git"
    
    for node_name in "${!CUSTOM_NODES[@]}"; do
        if [ -d "$node_name" ]; then
            print_warning "$node_name already installed. Updating..."
            cd "$node_name"
            git pull --quiet
            cd "$CUSTOM_NODES_DIR"
        else
            print_status "Installing $node_name..."
            git clone "${CUSTOM_NODES[$node_name]}"
        fi
        
        # Install node dependencies if requirements.txt exists
        if [ -f "$node_name/requirements.txt" ]; then
            if ! pip install -q -r "$node_name/requirements.txt" 2>&1; then
                print_warning "Failed to install some dependencies for $node_name. You may need to install them manually."
            fi
        fi
    done
    
    print_status "Custom nodes installed."
}

# Download required models
download_models() {
    print_status "Downloading required models..."
    
    MODELS_DIR="$COMFYUI_DIR/models"
    
    # Create model directories
    mkdir -p "$MODELS_DIR/vae"
    mkdir -p "$MODELS_DIR/diffusion_models"
    mkdir -p "$MODELS_DIR/text_encoders"
    mkdir -p "$MODELS_DIR/sams"
    mkdir -p "$MODELS_DIR/model_patches"
    mkdir -p "$MODELS_DIR/ultralytics/bbox"
    
    # Download models using wget with progress
    print_status "Downloading ae.safetensors (VAE)..."
    if [ ! -f "$MODELS_DIR/vae/ae.safetensors" ]; then
        wget -q --show-progress -O "$MODELS_DIR/vae/ae.safetensors" \
            "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors"
    else
        print_warning "ae.safetensors already exists, skipping..."
    fi
    
    print_status "Downloading z_image_turbo_bf16.safetensors (Diffusion Model)..."
    if [ ! -f "$MODELS_DIR/diffusion_models/z_image_turbo_bf16.safetensors" ]; then
        wget -q --show-progress -O "$MODELS_DIR/diffusion_models/z_image_turbo_bf16.safetensors" \
            "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors"
    else
        print_warning "z_image_turbo_bf16.safetensors already exists, skipping..."
    fi
    
    print_status "Downloading qwen_3_4b.safetensors (Text Encoder)..."
    if [ ! -f "$MODELS_DIR/text_encoders/qwen_3_4b.safetensors" ]; then
        wget -q --show-progress -O "$MODELS_DIR/text_encoders/qwen_3_4b.safetensors" \
            "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors"
    else
        print_warning "qwen_3_4b.safetensors already exists, skipping..."
    fi
    
    print_status "Downloading sam_vit_b_01ec64.pth (SAM Model)..."
    if [ ! -f "$MODELS_DIR/sams/sam_vit_b_01ec64.pth" ]; then
        wget -q --show-progress -O "$MODELS_DIR/sams/sam_vit_b_01ec64.pth" \
            "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth"
    else
        print_warning "sam_vit_b_01ec64.pth already exists, skipping..."
    fi
    
    print_status "Downloading Z-Image-Turbo-Fun-Controlnet-Union.safetensors (ControlNet)..."
    if [ ! -f "$MODELS_DIR/model_patches/Z-Image-Turbo-Fun-Controlnet-Union.safetensors" ]; then
        wget -q --show-progress -O "$MODELS_DIR/model_patches/Z-Image-Turbo-Fun-Controlnet-Union.safetensors" \
            "https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union.safetensors"
    else
        print_warning "Z-Image-Turbo-Fun-Controlnet-Union.safetensors already exists, skipping..."
    fi
    
    print_status "Downloading yolov8n-face.pt (Face Detection)..."
    if [ ! -f "$MODELS_DIR/ultralytics/bbox/yolov8n-face.pt" ]; then
        wget -q --show-progress -O "$MODELS_DIR/ultralytics/bbox/yolov8n-face.pt" \
            "https://huggingface.co/deepghs/yolo-face/resolve/739664f2d00e436a8882238f83175ab0f6497578/yolov8n-face/model.pt"
    else
        print_warning "yolov8n-face.pt already exists, skipping..."
    fi
    
    print_status "All models downloaded."
}

# Clone workflows repository and copy workflow files
setup_workflows() {
    print_status "Setting up SynthID-Bypass workflows..."
    
    if [ -d "$WORKFLOWS_DIR" ]; then
        print_warning "Workflows directory already exists. Updating..."
        cd "$WORKFLOWS_DIR"
        git pull --quiet
    else
        print_status "Cloning SynthID-Bypass repository..."
        git clone "$WORKFLOWS_REPO" "$WORKFLOWS_DIR"
    fi
    
    # Copy workflow files to ComfyUI input directory for easy access
    mkdir -p "$COMFYUI_DIR/user/default/workflows"
    if ls "$WORKFLOWS_DIR"/*.json 1> /dev/null 2>&1; then
        cp "$WORKFLOWS_DIR"/*.json "$COMFYUI_DIR/user/default/workflows/"
        print_status "Workflows copied to ComfyUI."
    else
        print_warning "No workflow .json files found in $WORKFLOWS_DIR"
    fi
}

# Create a startup script
create_startup_script() {
    print_status "Creating startup script..."
    
    cat > "$HOME/start_comfyui.sh" << 'EOF'
#!/bin/bash
# Start ComfyUI with remote access enabled for Paperspace

COMFYUI_DIR="${HOME}/ComfyUI"

echo "Starting ComfyUI..."
echo "Access ComfyUI at: http://localhost:8188"
echo "For remote access, use Paperspace's port forwarding or run with --listen 0.0.0.0"
echo ""

cd "$COMFYUI_DIR"
python main.py --listen 0.0.0.0 --port 8188
EOF
    
    chmod +x "$HOME/start_comfyui.sh"
    
    print_status "Startup script created at: $HOME/start_comfyui.sh"
}

# Print final instructions
print_instructions() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "To start ComfyUI, run:"
    echo -e "  ${YELLOW}~/start_comfyui.sh${NC}"
    echo ""
    echo -e "Or manually:"
    echo -e "  ${YELLOW}cd ~/ComfyUI && python main.py --listen 0.0.0.0${NC}"
    echo ""
    echo -e "Workflow files are located at:"
    echo -e "  ${YELLOW}~/Synthid-Bypass/*.json${NC}"
    echo ""
    echo -e "To use the workflows:"
    echo -e "  1. Open ComfyUI in your browser"
    echo -e "  2. Drag and drop one of the .json workflow files onto the canvas"
    echo -e "  3. Load your image and click 'Queue Prompt'"
    echo ""
    echo -e "${YELLOW}Note:${NC} If you're accessing ComfyUI remotely, make sure to:"
    echo -e "  - Use Paperspace's built-in port forwarding, or"
    echo -e "  - Set up SSH tunneling: ssh -L 8188:localhost:8188 your-paperspace-instance"
    echo ""
}

# Main installation flow
main() {
    check_cuda
    install_system_deps
    setup_comfyui
    install_comfyui_manager
    install_custom_nodes
    download_models
    setup_workflows
    create_startup_script
    print_instructions
}

# Run main function
main
