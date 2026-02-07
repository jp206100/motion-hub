#!/usr/bin/env python3
"""
extract.py - Motion Hub AI Preprocessing Pipeline

Extracts visual artifacts from inspiration media (images, videos, GIFs).
Runs at pack load time to generate textures, color palettes, motion patterns, etc.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import List, Dict, Any
import uuid
from datetime import datetime

import numpy as np
import cv2
from PIL import Image
from sklearn.cluster import KMeans


class ArtifactExtractor:
    """Main extraction pipeline for processing media files"""

    def __init__(self, output_dir: Path):
        self.output_dir = Path(output_dir)
        self.textures_dir = self.output_dir / "textures"
        self.clips_dir = self.output_dir / "clips"
        self.motion_dir = self.output_dir / "motion"

        # Create output directories
        self.textures_dir.mkdir(parents=True, exist_ok=True)
        self.clips_dir.mkdir(parents=True, exist_ok=True)
        self.motion_dir.mkdir(parents=True, exist_ok=True)

        self.texture_counter = 0
        self.clip_counter = 0
        self.motion_counter = 0

    def process_pack(self, media_files: List[Path], pack_id: str) -> Dict[str, Any]:
        """
        Main entry point - process all media in a pack

        Args:
            media_files: List of media file paths
            pack_id: UUID of the pack

        Returns:
            Dictionary containing all extracted artifacts
        """
        artifacts = {
            "pack_id": pack_id,
            "created_at": datetime.now().isoformat(),
            "source_media": [],
            "artifacts": {
                "color_palettes": [],
                "textures": [],
                "motion_patterns": [],
                "video_clips": [],
                "ghosted_images": []
            }
        }

        for media_file in media_files:
            if not media_file.exists():
                print(f"Warning: File not found: {media_file}", file=sys.stderr)
                continue

            media_type = self._determine_media_type(media_file)
            artifacts["source_media"].append({
                "filename": media_file.name,
                "type": media_type
            })

            print(f"Processing {media_file.name} ({media_type})...")

            try:
                if media_type == "image":
                    self._process_image(media_file, artifacts)
                elif media_type in ["video", "gif"]:
                    self._process_video(media_file, artifacts)
            except Exception as e:
                print(f"Error processing {media_file.name}: {e}", file=sys.stderr)

        return artifacts

    def _process_image(self, image_path: Path, artifacts: Dict[str, Any]):
        """Process a single image file"""
        # Extract color palette
        palettes = self.extract_colors(image_path)
        artifacts["artifacts"]["color_palettes"].extend(palettes)

        # Extract textures
        textures = self.extract_textures(image_path)
        artifacts["artifacts"]["textures"].extend(textures)

        # Create ghosted versions
        ghosted = self.create_ghosted(image_path)
        artifacts["artifacts"]["ghosted_images"].extend(ghosted)

    def _process_video(self, video_path: Path, artifacts: Dict[str, Any]):
        """Process a video or GIF file"""
        # Extract color palette from first frame
        palettes = self.extract_colors_from_video(video_path)
        artifacts["artifacts"]["color_palettes"].extend(palettes)

        # Extract textures from key frames
        textures = self.extract_video_textures(video_path)
        artifacts["artifacts"]["textures"].extend(textures)

        # Extract motion patterns
        motion = self.extract_motion(video_path)
        artifacts["artifacts"]["motion_patterns"].extend(motion)

        # Extract and process clips
        clips = self.extract_clips(video_path)
        artifacts["artifacts"]["video_clips"].extend(clips)

    def extract_colors(self, image_path: Path) -> List[Dict[str, Any]]:
        """Extract dominant color palette using k-means clustering"""
        img = Image.open(image_path).convert('RGB')
        img = img.resize((150, 150))  # Downsample for speed
        pixels = np.array(img).reshape(-1, 3)

        # Use k-means to find 6 dominant colors
        n_colors = 6
        kmeans = KMeans(n_clusters=n_colors, random_state=42, n_init=10)
        kmeans.fit(pixels)

        # Convert to hex colors
        colors = []
        for color in kmeans.cluster_centers_:
            hex_color = "#{:02x}{:02x}{:02x}".format(
                int(color[0]), int(color[1]), int(color[2])
            )
            colors.append(hex_color)

        return [{
            "id": str(uuid.uuid4()),
            "colors": colors,
            "source": image_path.name
        }]

    def extract_colors_from_video(self, video_path: Path) -> List[Dict[str, Any]]:
        """Extract colors from first frame of video"""
        cap = cv2.VideoCapture(str(video_path))
        ret, frame = cap.read()
        cap.release()

        if not ret:
            return []

        # Save frame as temp image and process
        temp_img = self.output_dir / "temp_frame.png"
        cv2.imwrite(str(temp_img), frame)
        try:
            result = self.extract_colors(temp_img)
        finally:
            temp_img.unlink(missing_ok=True)

        return result

    def extract_textures(self, image_path: Path) -> List[Dict[str, Any]]:
        """Generate texture variations from an image"""
        img = cv2.imread(str(image_path), cv2.IMREAD_GRAYSCALE)
        if img is None:
            return []

        textures = []

        # 1. Edge detection (Canny)
        edges = cv2.Canny(img, 50, 150)
        edge_file = self.textures_dir / f"texture_{self.texture_counter:03d}_edges.png"
        cv2.imwrite(str(edge_file), edges)
        textures.append({
            "id": str(uuid.uuid4()),
            "filename": edge_file.name,
            "source": image_path.name,
            "type": "edge_map"
        })
        self.texture_counter += 1

        # 2. High-pass filter for detail extraction
        blurred = cv2.GaussianBlur(img, (21, 21), 0)
        highpass = cv2.subtract(img, blurred)
        highpass_file = self.textures_dir / f"texture_{self.texture_counter:03d}_highpass.png"
        cv2.imwrite(str(highpass_file), highpass)
        textures.append({
            "id": str(uuid.uuid4()),
            "filename": highpass_file.name,
            "source": image_path.name,
            "type": "processed"
        })
        self.texture_counter += 1

        # 3. Posterization
        posterized = (img // 64) * 64
        poster_file = self.textures_dir / f"texture_{self.texture_counter:03d}_poster.png"
        cv2.imwrite(str(poster_file), posterized)
        textures.append({
            "id": str(uuid.uuid4()),
            "filename": poster_file.name,
            "source": image_path.name,
            "type": "posterized"
        })
        self.texture_counter += 1

        return textures

    def extract_video_textures(self, video_path: Path) -> List[Dict[str, Any]]:
        """Extract textures from video key frames"""
        cap = cv2.VideoCapture(str(video_path))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

        if total_frames == 0:
            cap.release()
            return []

        # Extract frame from middle
        cap.set(cv2.CAP_PROP_POS_FRAMES, total_frames // 2)
        ret, frame = cap.read()
        cap.release()

        if not ret:
            return []

        # Save frame and process
        temp_img = self.output_dir / "temp_video_frame.png"
        cv2.imwrite(str(temp_img), frame)
        try:
            result = self.extract_textures(temp_img)
        finally:
            temp_img.unlink(missing_ok=True)

        return result

    def extract_motion(self, video_path: Path) -> List[Dict[str, Any]]:
        """Extract motion patterns using optical flow"""
        cap = cv2.VideoCapture(str(video_path))

        ret, prev_frame = cap.read()
        if not ret:
            cap.release()
            return []

        prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)

        # Read next frame
        ret, frame = cap.read()
        if not ret:
            cap.release()
            return []

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        # Calculate optical flow
        flow = cv2.calcOpticalFlowFarneback(
            prev_gray, gray, None,
            pyr_scale=0.5, levels=3, winsize=15,
            iterations=3, poly_n=5, poly_sigma=1.2, flags=0
        )

        cap.release()

        # Save flow visualization
        hsv = np.zeros((flow.shape[0], flow.shape[1], 3), dtype=np.uint8)
        hsv[..., 1] = 255

        mag, ang = cv2.cartToPolar(flow[..., 0], flow[..., 1])
        hsv[..., 0] = ang * 180 / np.pi / 2
        hsv[..., 2] = cv2.normalize(mag, None, 0, 255, cv2.NORM_MINMAX)
        flow_rgb = cv2.cvtColor(hsv, cv2.COLOR_HSV2BGR)

        motion_file = self.motion_dir / f"motion_{self.motion_counter:03d}.png"
        cv2.imwrite(str(motion_file), flow_rgb)

        self.motion_counter += 1

        return [{
            "id": str(uuid.uuid4()),
            "filename": motion_file.name,
            "source": video_path.name,
            "type": "optical_flow"
        }]

    def extract_clips(self, video_path: Path) -> List[Dict[str, Any]]:
        """Extract and process video clips"""
        # For now, just copy the original
        # In production, you'd use ffmpeg to extract clips, time-stretch, etc.
        clips = []

        # This would normally use ffmpeg-python to:
        # 1. Extract short clips (2-5 seconds)
        # 2. Create time-stretched versions
        # 3. Create reversed versions

        # Placeholder - just reference the original
        cap = cv2.VideoCapture(str(video_path))
        duration = cap.get(cv2.CAP_PROP_FRAME_COUNT) / cap.get(cv2.CAP_PROP_FPS)
        cap.release()

        clips.append({
            "id": str(uuid.uuid4()),
            "filename": video_path.name,
            "source": video_path.name,
            "duration": duration,
            "stretched": False
        })

        return clips

    def create_ghosted(self, image_path: Path) -> List[Dict[str, Any]]:
        """Create ghosted/processed image versions"""
        img = cv2.imread(str(image_path))
        if img is None:
            return []

        ghosted = []

        # High contrast version
        contrast = cv2.convertScaleAbs(img, alpha=1.5, beta=0)
        contrast_file = self.textures_dir / f"ghost_{self.texture_counter:03d}_contrast.png"
        cv2.imwrite(str(contrast_file), contrast)
        ghosted.append({
            "id": str(uuid.uuid4()),
            "filename": contrast_file.name,
            "source": image_path.name,
            "opacity": 0.5
        })
        self.texture_counter += 1

        # Desaturated version
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        desat = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
        desat_file = self.textures_dir / f"ghost_{self.texture_counter:03d}_desat.png"
        cv2.imwrite(str(desat_file), desat)
        ghosted.append({
            "id": str(uuid.uuid4()),
            "filename": desat_file.name,
            "source": image_path.name,
            "opacity": 0.3
        })
        self.texture_counter += 1

        return ghosted

    @staticmethod
    def _determine_media_type(path: Path) -> str:
        """Determine media type from file extension"""
        ext = path.suffix.lower()
        if ext in ['.jpg', '.jpeg', '.png', '.heic', '.tiff', '.bmp']:
            return 'image'
        elif ext == '.gif':
            return 'gif'
        elif ext in ['.mp4', '.mov', '.m4v', '.avi', '.mkv']:
            return 'video'
        return 'unknown'


def main():
    parser = argparse.ArgumentParser(description='Extract visual artifacts from media files')
    parser.add_argument('--input', required=True, help='Comma-separated list of input media files')
    parser.add_argument('--output', required=True, help='Output directory for artifacts')
    parser.add_argument('--pack-id', default=str(uuid.uuid4()), help='Pack UUID')

    args = parser.parse_args()

    # Parse input files
    input_files = [Path(f.strip()) for f in args.input.split(',')]
    output_dir = Path(args.output).resolve()

    # Validate that output directory is within Application Support or a reasonable location
    # (reject writes to system directories)
    _BLOCKED_PREFIXES = ['/etc', '/usr', '/bin', '/sbin', '/var', '/System', '/private/etc']
    for blocked in _BLOCKED_PREFIXES:
        if str(output_dir).startswith(blocked):
            print(f"Error: output directory '{output_dir}' is in a restricted location", file=sys.stderr)
            sys.exit(1)

    # Validate input files: must exist and have a supported media extension
    _ALLOWED_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.heic', '.tiff', '.bmp',
                           '.gif', '.mp4', '.mov', '.m4v', '.avi', '.mkv'}
    validated_files = []
    for f in input_files:
        resolved = f.resolve()
        if not resolved.exists():
            print(f"Warning: Skipping non-existent file: {f}", file=sys.stderr)
            continue
        if resolved.suffix.lower() not in _ALLOWED_EXTENSIONS:
            print(f"Warning: Skipping unsupported file type: {f}", file=sys.stderr)
            continue
        validated_files.append(resolved)

    if not validated_files:
        print("Error: No valid input files to process", file=sys.stderr)
        sys.exit(1)

    input_files = validated_files

    # Create extractor and process
    extractor = ArtifactExtractor(output_dir)
    artifacts = extractor.process_pack(input_files, args.pack_id)

    # Save artifacts manifest
    manifest_path = output_dir / "artifacts.json"
    with open(manifest_path, 'w') as f:
        json.dump(artifacts, f, indent=2)

    print(f"\nProcessing complete!")
    print(f"Artifacts saved to: {output_dir}")
    print(f"- {len(artifacts['artifacts']['color_palettes'])} color palettes")
    print(f"- {len(artifacts['artifacts']['textures'])} textures")
    print(f"- {len(artifacts['artifacts']['motion_patterns'])} motion patterns")
    print(f"- {len(artifacts['artifacts']['video_clips'])} video clips")
    print(f"- {len(artifacts['artifacts']['ghosted_images'])} ghosted images")


if __name__ == '__main__':
    main()
