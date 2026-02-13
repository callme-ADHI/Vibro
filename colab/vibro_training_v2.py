# ═══════════════════════════════════════════════════
# 🔷 VIBRO — Advanced Training Pipeline (v2.0)
# ═══════════════════════════════════════════════════
# This script handles the end-to-end training process for Vibro.
# It aligns perfectly with the Dart app's feature extraction.
# ═══════════════════════════════════════════════════

import os
import sys
import json
import shutil
import subprocess
import traceback
import numpy as np
from datetime import datetime

# ── Install Dependencies ──
def install_dependencies():
    packages = ["supabase", "tensorflow", "librosa", "scikit-learn", "numpy", "scipy"]
    try:
        import importlib
        for pkg in packages:
            importlib.import_module(pkg)
    except ImportError:
        print("📦 Installing dependencies... (this may take a minute)")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-q"] + packages)
        print("✅ Dependencies installed.")

install_dependencies()

import librosa
import tensorflow as tf
from supabase import create_client, Client
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split

# ═══════════════════════════════════════════════════
# ⚙️ CONFIGURATION
# ═══════════════════════════════════════════════════

# Force retrain even if models exist (useful after algorithm updates)
FORCE_RETRAIN = True 

# Audio Parameters (MUST MATCH DART APP)
SAMPLE_RATE = 16000
N_MFCC = 13
N_MELS = 128
N_FFT = 2048
HOP_LENGTH = 512

# Buckets
BUCKET_AUDIO = "audio_submissions"
BUCKET_MODELS = "trained_models"

# Local Directories
DATASET_DIR = "./vibro_dataset"

# Supabase Credentials
SUPABASE_URL = "https://pqtjvdfcitdpveuqzgpk.supabase.co"
# Securely prompt for key if not in env
if "SUPABASE_KEY" in os.environ:
    SUPABASE_KEY = os.environ["SUPABASE_KEY"]
else:
    print("\n🔐 CREDENTIALS REQUIRED")
    print(f"Target Project: {SUPABASE_URL}")
    SUPABASE_KEY = input("Enter Supabase Service Key: ").strip()

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)


# ═══════════════════════════════════════════════════
# 🧠 FEATURE EXTRACTION (The Core Math)
# ═══════════════════════════════════════════════════

def extract_features(file_path):
    """
    Extracts MFCC features from an audio file.
    
    ALGORITHM:
    1. Resample to 16kHz
    2. Extract 13 MFCCs
    3. Use HTK Mel Filters + Slaney Normalization (Librosa default)
    4. Use Log-dB Scaling
    5. Compute Mean over time
    """
    try:
        # Load audio
        audio, _ = librosa.load(file_path, sr=SAMPLE_RATE)
        
        # Trim silence (improves mean quality)
        audio, _ = librosa.effects.trim(audio, top_db=20)
        
        # Extract MFCCs
        # n_mels=128, htk=True matches Dart implementation
        # norm='slaney' is default in librosa, matches Dart
        mfcc = librosa.feature.mfcc(
            y=audio, 
            sr=SAMPLE_RATE, 
            n_mfcc=N_MFCC, 
            n_mels=N_MELS, 
            n_fft=N_FFT, 
            hop_length=HOP_LENGTH,
            htk=True,            # VITAL: Dart uses HTK mel formula
            window='hamming'     # VITAL: Dart uses Hamming window
        )
        
        # Compute Mean (Global Average Pooling) -> [N_MFCC]
        # Dart also computes simple mean of the buffer
        mfcc_mean = np.mean(mfcc, axis=1)
        
        return mfcc_mean
    except Exception as e:
        print(f"      ⚠️ Error extracting {os.path.basename(file_path)}: {e}")
        return None

# ═══════════════════════════════════════════════════
# 🔊 DATA AUGMENTATION
# ═══════════════════════════════════════════════════

def generate_augmentations(file_path):
    """Generates augmented versions of the audio (Noise, Pitch, Speed)"""
    try:
        y, sr = librosa.load(file_path, sr=SAMPLE_RATE)
        augmented_clips = []
        
        # 1. Noise
        noise = np.random.randn(len(y)) * 0.005
        augmented_clips.append(y + noise)
        
        # 2. Pitch +2
        augmented_clips.append(librosa.effects.pitch_shift(y, sr=sr, n_steps=2))
        
        # 3. Pitch -2
        augmented_clips.append(librosa.effects.pitch_shift(y, sr=sr, n_steps=-2))
        
        # 4. Speed 1.1x
        augmented_clips.append(librosa.effects.time_stretch(y, rate=1.1))
        
        # 5. Speed 0.9x
        augmented_clips.append(librosa.effects.time_stretch(y, rate=0.9))
        
        return augmented_clips
    except:
        return []

def extract_features_from_array(y):
    """Helper for augmented arrays"""
    try:
        mfcc = librosa.feature.mfcc(
            y=y, sr=SAMPLE_RATE, n_mfcc=N_MFCC, n_mels=N_MELS, 
            n_fft=N_FFT, hop_length=HOP_LENGTH, htk=True, window='hamming'
        )
        return np.mean(mfcc, axis=1)
    except:
        return None

# ═══════════════════════════════════════════════════
# 🛠️ UTILITIES
# ═══════════════════════════════════════════════════

def update_db_status(user_id, status, progress, error=None, model_version=None):
    """Updates the user_training_status table"""
    payload = {
        "status": status,
        "progress_percentage": progress,
        "updated_at": datetime.utcnow().isoformat()
    }
    if error: payload["error_message"] = str(error)
    if model_version: payload["model_version"] = model_version
    
    try:
        # Upsert status
        existing = supabase.table("user_training_status").select("id").eq("user_id", user_id).execute()
        if existing.data:
            supabase.table("user_training_status").update(payload).eq("user_id", user_id).execute()
        else:
            payload["user_id"] = user_id
            supabase.table("user_training_status").insert(payload).execute()
    except Exception as e:
        print(f"      ⚠️ DB Update Error: {e}")

def generate_background_noise(count=60):
    """Generates synthetic background noise samples"""
    noise_dir = os.path.join(DATASET_DIR, "_background_noise_")
    os.makedirs(noise_dir, exist_ok=True)
    
    import scipy.io.wavfile
    for i in range(count):
        if i < 10: # Silence
             audio = np.zeros(SAMPLE_RATE)
        elif i < 30: # White
            audio = np.random.randn(SAMPLE_RATE) * 0.005
        else: # Brownish
            audio = np.cumsum(np.random.randn(SAMPLE_RATE))
            audio = audio / np.max(np.abs(audio)) * 0.005
            
        scipy.io.wavfile.write(
            os.path.join(noise_dir, f"noise_{i}.wav"), 
            SAMPLE_RATE, 
            (audio * 32767).astype(np.int16)
        )
    return noise_dir

# ═══════════════════════════════════════════════════
# 🎓 TRAINING PIPELINE (PER USER)
# ═══════════════════════════════════════════════════

def train_user_model(user_id, user_names):
    print(f"\n🚀 STARTING PIPELINE: {user_id}")
    update_db_status(user_id, "DOWNLOADING_AUDIO", 10)
    
    # 1. PREPARE DATASET
    if os.path.exists(DATASET_DIR): shutil.rmtree(DATASET_DIR)
    os.makedirs(DATASET_DIR, exist_ok=True)
    
    features = []
    labels = []
    
    # 1a. Download User Audio
    total_downloaded = 0
    for name_obj in user_names:
        label = name_obj["name_label"]
        name_id = name_obj["id"]
        
        # Download files
        storage_path = f"{user_id}/{name_id}"
        local_path = os.path.join(DATASET_DIR, label)
        os.makedirs(local_path, exist_ok=True)
        
        try:
            files = supabase.storage.from_(BUCKET_AUDIO).list(storage_path)
            valid_files = [f for f in files if f['name'].endswith('.wav')]
            
            print(f"   Downloading '{label}' ({len(valid_files)} clips)...")
            
            for f in valid_files:
                data = supabase.storage.from_(BUCKET_AUDIO).download(f"{storage_path}/{f['name']}")
                save_path = os.path.join(local_path, f['name'])
                with open(save_path, "wb") as wav_file:
                    wav_file.write(data)
                
                # Extract Features immediately
                feats = extract_features(save_path)
                if feats is not None:
                    features.append(feats)
                    labels.append(label)
                    
                    # Augment
                    aug_clips = generate_augmentations(save_path)
                    for clip in aug_clips:
                        af = extract_features_from_array(clip)
                        if af is not None:
                            features.append(af)
                            labels.append(label)
                            
                total_downloaded += 1
        except Exception as e:
            print(f"      ⚠️ Failed to download {label}: {e}")

    if total_downloaded == 0:
        print("   ❌ No audio found.")
        update_db_status(user_id, "FAILED", 0, "No audio files found")
        return False

    update_db_status(user_id, "PROCESSING_AUDIO", 30)

    # 1b. Generate & Extract Background Noise
    noise_dir = generate_background_noise()
    print("   Generating Background Noise...")
    for f in os.listdir(noise_dir):
        fp = os.path.join(noise_dir, f)
        feats = extract_features(fp)
        if feats is not None:
            features.append(feats)
            labels.append("_background_noise_")

    print(f"   📊 Total Training Samples: {len(features)}")
    
    if len(features) < 10:
        print("   ❌ Not enough data points.")
        update_db_status(user_id, "FAILED", 0, "Insufficient data")
        return False

    # 2. MODEL TRAINING
    update_db_status(user_id, "TRAINING", 50)
    
    X = np.array(features)
    le = LabelEncoder()
    y = le.fit_transform(labels)
    num_classes = len(le.classes_)
    
    # Split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Build MLP Model
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(N_MFCC,)),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(num_classes, activation='softmax')
    ])
    
    model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])
    
    # Train
    model.fit(X_train, y_train, epochs=60, batch_size=16, verbose=0, validation_data=(X_test, y_test))
    
    loss, acc = model.evaluate(X_test, y_test, verbose=0)
    print(f"   🎯 Model Accuracy: {acc:.4f}")
    
    # 3. EXPORT & UPLOAD
    update_db_status(user_id, "UPLOADING_MODEL", 80)
    
    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    
    # Save Labels
    label_map = {int(i): l for i, l in enumerate(le.classes_)}
    
    # Upload to Supabase
    version = int(datetime.utcnow().timestamp())
    model_path = f"{user_id}/model_v{version}.tflite"
    labels_path = f"{user_id}/labels_v{version}.json"
    
    try:
        # Upload TFLite
        supabase.storage.from_(BUCKET_MODELS).upload(
            model_path, tflite_model, 
            file_options={"content-type": "application/octet-stream", "upsert": "true"}
        )
        
        # Upload Labels
        supabase.storage.from_(BUCKET_MODELS).upload(
            labels_path, json.dumps(label_map).encode(), 
            file_options={"content-type": "application/json", "upsert": "true"}
        )
        
        # Register Model in DB
        # Delete old
        supabase.table("trained_models").delete().eq("user_id", user_id).execute()
        # Insert new
        supabase.table("trained_models").insert({
            "user_id": user_id,
            "trained_name_id": user_names[0]["id"], # Link to first name
            "model_version": version,
            "model_path": model_path,
            "training_sample_count": total_downloaded,
            "accuracy_metric": float(acc)
        }).execute()
        
        update_db_status(user_id, "COMPLETED", 100, model_version=version)
        print("   ✅ Training Complete & Uploaded!")
        return True
        
    except Exception as e:
        print(f"   ❌ Upload Failed: {e}")
        update_db_status(user_id, "FAILED", 0, str(e))
        return False


# ═══════════════════════════════════════════════════
# 🕵️ MAIN LOOP (FIND & TRAIN)
# ═══════════════════════════════════════════════════

def main():
    print(f"\n{'='*60}")
    print("      🔊 VIBRO MODEL TRAINER DETECTOR      ")
    print(f"{'='*60}\n")
    
    try:
        # 1. Identify Users
        # Get unique user IDs from audio submissions
        res = supabase.table(BUCKET_AUDIO).select("user_id").execute()
        users = list(set([x['user_id'] for x in res.data]))
        
        print(f"🔎 Found {len(users)} users with audio content.")
        
        processed_count = 0
        
        for uid in users:
            # Check if training needed
            names_res = supabase.table("trained_names").select("*").eq("user_id", uid).execute()
            if not names_res.data:
                continue # No configured names
                
            # Check existing model
            model_res = supabase.table("trained_models").select("model_version").eq("user_id", uid).execute()
            
            should_train = False
            reason = ""
            
            if not model_res.data:
                should_train = True
                reason = "No model exists"
            elif FORCE_RETRAIN:
                should_train = True
                reason = "FORCE_RETRAIN enabled"
            else:
                # Add logic here to check if new audio exists if needed
                pass
                
            if should_train:
                print(f"\n👤 User: {uid} | Reason: {reason}")
                
                # Force status reset
                supabase.table("user_training_status").delete().eq("user_id", uid).execute()
                
                success = train_user_model(uid, names_res.data)
                if success: processed_count += 1
                
        print(f"\n{'='*60}")
        print(f"🏁 DONE: Trained {processed_count} models.")
        print(f"{'='*60}")

    except Exception as e:
        print(f"\n💥 CRITICAL: {e}")
        traceback.print_exc()

if __name__ == "__main__":
    main()
