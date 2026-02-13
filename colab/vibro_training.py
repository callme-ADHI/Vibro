# ═══════════════════════════════════════════════════
# 🔷 VIBRO — Automatic Training Pipeline
# ═══════════════════════════════════════════════════
# INSTRUCTIONS:
#   1. Open Google Colab (colab.research.google.com)
#   2. Go to Runtime → Change runtime type → GPU
#   3. Create a new cell, paste ALL of this code
#   4. Click Run (▶) — it will auto-find & train all
#      users who have uploaded audio but no model yet
# ═══════════════════════════════════════════════════

# ──── Install dependencies ────
import subprocess
subprocess.check_call(["pip", "install", "-q", "supabase", "tensorflow", "librosa", "scikit-learn", "numpy", "scipy"])

import os, json, shutil
import numpy as np
import librosa
import tensorflow as tf
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from supabase import create_client, Client
from datetime import datetime

print(f"TensorFlow: {tf.__version__}")
print(f"GPU: {tf.config.list_physical_devices('GPU')}")

# ═══════════════════════════════════════════════════
# CONFIG (service role key — keep private)
# ═══════════════════════════════════════════════════
# Configuration
# Updated credentials
# Credentials Input (User must provide at runtime)
# IMPORTANT: DO NOT COMMIT REAL KEYS TO GIT
SUPABASE_URL = "https://pqtjvdfcitdpveuqzgpk.supabase.co"
SUPABASE_SERVICE_KEY = input("Enter Supabase Service Key (starts with sb_service_role...): ").strip() if "get_ipython" in globals() else os.environ.get("SUPABASE_KEY", "YOUR_SERVICE_KEY_HERE")

if SUPABASE_SERVICE_KEY.startswith("sb_publishable"):
    print("\n⚠️ WARNING: You have entered a PUBLIC ANON KEY (sb_publishable...).")
    print("   This script requires the SERVICE ROLE SECRET (starts with sb_service_role...) to see all user data.")
    print("   Please go to Supabase Dashboard -> Settings -> API -> service_role secret.")
    print("   Without it, no records will be found due to Row Level Security (RLS).\n")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

AUDIO_BUCKET = "audio_submissions"
MODELS_BUCKET = "trained_models"
SAMPLE_RATE = 16000
N_MFCC = 13
MAX_PAD_LEN = 64 # Kept for consistency, though mean doesn't strictly need padding if we just avg what we have
DATASET_DIR = "./dataset"

print("✅ Supabase connected")


# ──── HELPER: Update training status ────
def update_status(user_id, status, progress, error_message=None, model_version=None):
    data = {
        "status": status,
        "progress_percentage": progress,
        "updated_at": datetime.utcnow().isoformat(),
    }
    if error_message is not None:
        data["error_message"] = error_message
    if model_version is not None:
        data["model_version"] = model_version

    existing = supabase.table("user_training_status").select("id").eq("user_id", user_id).execute()
    if existing.data:
        supabase.table("user_training_status").update(data).eq("user_id", user_id).execute()
    else:
        data["user_id"] = user_id
        names = supabase.table("trained_names").select("id").eq("user_id", user_id).limit(1).execute()
        if names.data:
            data["trained_name_id"] = names.data[0]["id"]
        supabase.table("user_training_status").insert(data).execute()
    print(f"   📊 {status} | {progress}%")


# ──── HELPER: Extract MFCC (Legacy Mean Algorithm) ────
def extract_mfcc(audio, sr=SAMPLE_RATE):
    """Extract MFCC from raw audio array and compute MEAN over time."""
    try:
        # 1. Extract MFCCs (n_mfcc, time)
        # 1. Extract MFCCs (n_mfcc, time)
        # CRITICAL: Match Dart implementation parameters!
        # - htk=True: Use HTK mel filters (Dart uses HTK formula)
        # - window='hamming': Dart uses Hamming window
        # - n_mels=128: Explicitly set (Dart uses 128)
        mfcc = librosa.feature.mfcc(
            y=audio, sr=sr, n_mfcc=N_MFCC, 
            n_mels=128, n_fft=2048, hop_length=512, 
            htk=True, window='hamming'
        )
        
        # 2. Compute Mean across time axis (axis=1) -> shape (n_mfcc,)
        # The user's old script utilized np.mean(mfcc.T, axis=0), which is equivalent.
        mfcc_mean = np.mean(mfcc, axis=1)
        
        return mfcc_mean
    except:
        return None


def load_audio(file_path):
    """Load a WAV file and return raw audio array."""
    try:
        audio, _ = librosa.load(file_path, sr=SAMPLE_RATE)
        # Trim silence (optional, but good for mean features)
        audio, _ = librosa.effects.trim(audio)
        return audio
    except Exception as e:
        print(f"      ⚠️ {os.path.basename(file_path)}: {e}")
        return None


# ──── HELPER: Audio Augmentation ────
# Creates 5 variations per clip → 10 clips become 60 samples

def augment_noise(audio, noise_level=0.005):
    """Add random Gaussian noise."""
    noise = np.random.randn(len(audio)) * noise_level
    return audio + noise

def augment_pitch(audio, sr=SAMPLE_RATE, n_steps=2):
    """Shift pitch up or down."""
    return librosa.effects.pitch_shift(y=audio, sr=sr, n_steps=n_steps)

def augment_stretch(audio, rate=1.1):
    """Time-stretch audio."""
    return librosa.effects.time_stretch(y=audio, rate=rate)

def augment_volume(audio, factor=1.5):
    """Change volume."""
    return audio * factor

def augment_combined(audio, sr=SAMPLE_RATE):
    """Noise + slight pitch shift."""
    aug = augment_noise(audio, noise_level=0.003)
    aug = librosa.effects.pitch_shift(y=aug, sr=sr, n_steps=-1)
    return aug

def get_augmented_versions(audio):
    """Return list of (label_suffix, augmented_audio) tuples."""
    augmented = []
    try:
        augmented.append(augment_noise(audio))
    except: pass
    try:
        augmented.append(augment_pitch(audio, n_steps=2))
    except: pass
    try:
        augmented.append(augment_pitch(audio, n_steps=-2))
    except: pass
    try:
        augmented.append(augment_stretch(audio, rate=0.9))
    except: pass
    try:
        augmented.append(augment_combined(audio))
    except: pass
    return augmented


# ──── HELPER: Generate Synthetic Noise ────
def generate_noise_samples(output_dir, count=60):
    """Generate synthetic noise samples (white, pink, brown, silence)."""
    os.makedirs(output_dir, exist_ok=True)
    print(f"   Generating {count} background noise samples...")
    
    for i in range(count):
        # 1. Silence (0.0)
        if i < 10:
            audio = np.zeros(SAMPLE_RATE) # 1 sec silence
            name = f"silence_{i}.wav"
        
        # 2. White Noise
        elif i < 30:
            audio = np.random.randn(SAMPLE_RATE) * 0.005
            name = f"white_{i}.wav"
            
        # 3. Pink/Brown-ish (cumulative sum of white noise)
        else:
            white = np.random.randn(SAMPLE_RATE)
            brown = np.cumsum(white)
            brown = brown / np.max(np.abs(brown)) * 0.005 # normalize
            audio = brown
            name = f"brown_{i}.wav"
            
        # Save as WAV
        import scipy.io.wavfile
        scipy.io.wavfile.write(
            os.path.join(output_dir, name), 
            SAMPLE_RATE, 
            (audio * 32767).astype(np.int16)
        )



# ──── HELPER: Train one user ────
def train_user(user_id, trained_names):
    print(f"\n{'━' * 50}")
    print(f"🧑 Training user: {user_id[:8]}...")
    print(f"   Names: {[n['name_label'] for n in trained_names]}")
    print(f"{'━' * 50}")

    try:
        update_status(user_id, "DOWNLOADING_AUDIO", 10)

        # ── Download audio ──
        if os.path.exists(DATASET_DIR):
            shutil.rmtree(DATASET_DIR)

        total_samples = 0
        for entry in trained_names:
            name_id, label = entry["id"], entry["name_label"]
            name_dir = os.path.join(DATASET_DIR, label)
            os.makedirs(name_dir, exist_ok=True)

            storage_path = f"{user_id}/{name_id}"
            try:
                files = supabase.storage.from_(AUDIO_BUCKET).list(storage_path)
            except:
                continue

            wav_files = [f for f in files if f["name"].endswith(".wav")]
            for wav in wav_files:
                try:
                    data = supabase.storage.from_(AUDIO_BUCKET).download(f"{storage_path}/{wav['name']}")
                    with open(os.path.join(name_dir, wav["name"]), "wb") as f:
                        f.write(data)
                    total_samples += 1
                except:
                    pass

            print(f"   📥 {label}: {len(wav_files)} samples")

        if total_samples == 0:
            update_status(user_id, "FAILED", 0, error_message="No audio samples found")
            return False

        update_status(user_id, "DOWNLOADING_AUDIO", 30)

        update_status(user_id, "DOWNLOADING_AUDIO", 30)

        # ── Generate Background Noise Class ──
        noise_dir = os.path.join(DATASET_DIR, "_background_noise_")
        generate_noise_samples(noise_dir, count=60)
        
        # Add to trained names list for processing
        processing_names = trained_names + [{"id": "noise", "name_label": "_background_noise_"}]

        # ── Feature extraction + augmentation ──
        features, labels = [], []
        for entry in processing_names:
            name_dir = os.path.join(DATASET_DIR, entry["name_label"])
            if not os.path.exists(name_dir):
                continue
            for wav in sorted(os.listdir(name_dir)):
                if not wav.endswith(".wav"):
                    continue
                audio = load_audio(os.path.join(name_dir, wav))
                if audio is None:
                    continue

                # Original
                mfcc = extract_mfcc(audio)
                if mfcc is not None:
                    features.append(mfcc)
                    labels.append(entry["name_label"])

                # Augmented versions (5 extra per clip)
                for aug_audio in get_augmented_versions(audio):
                    aug_mfcc = extract_mfcc(aug_audio)
                    if aug_mfcc is not None:
                        features.append(aug_mfcc)
                        labels.append(entry["name_label"])

        print(f"   🔊 Augmented: {len(features)} total samples (from {total_samples} original clips)")

        if len(features) < 2:
            update_status(user_id, "FAILED", 0, error_message="Not enough valid samples for training")
            return False

        X = np.array(features)
        label_encoder = LabelEncoder()
        y = label_encoder.fit_transform(labels)
        num_classes = len(label_encoder.classes_)

        # Normalization (Crucial: Match Dart implementation!)
        # Old algorithm didn't explicitly normalize like the previous one, 
        # but let's do standard scaler or min-max?
        # The provided user script DID NOT normalize features before training (other than librosa default).
        # We will assume raw MFCCs.
        
        # Split
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42,
            stratify=y if len(set(y)) > 1 and min(np.bincount(y)) >= 2 else None
        )

        print(f"   🔬 Shape: {X.shape} | Classes: {list(label_encoder.classes_)}")
        update_status(user_id, "TRAINING", 40)

        # ── Train model (Legacy Architecture) ──
        # Simple MLP matching the user's provided script
        model = tf.keras.Sequential([
            tf.keras.layers.Input(shape=(N_MFCC,)), # 13 features
            tf.keras.layers.Dense(64, activation='relu'),
            tf.keras.layers.Dropout(0.3),
            tf.keras.layers.Dense(32, activation='relu'),
            tf.keras.layers.Dropout(0.3),
            tf.keras.layers.Dense(num_classes, activation='softmax'), # Multiclass
        ])
        
        optimizer = tf.keras.optimizers.Adam(learning_rate=0.001)
        model.compile(optimizer=optimizer, loss='sparse_categorical_crossentropy', metrics=['accuracy'])

        EPOCHS = 60 # Reduced epochs for simpler model

        class ProgressCB(tf.keras.callbacks.Callback):
            def on_epoch_end(self, epoch, logs=None):
                if (epoch + 1) % 10 == 0 or (epoch + 1) == EPOCHS:
                    progress = 40 + int((epoch + 1) / EPOCHS * 40)
                    acc = logs.get('accuracy', 0)
                    print(f"      Epoch {epoch+1}/{EPOCHS} — acc: {acc:.4f}")
                    try:
                        update_status(user_id, "TRAINING", min(progress, 80))
                    except:
                        pass

        model.fit(
            X_train, y_train,
            epochs=EPOCHS, batch_size=16,
            validation_data=(X_test, y_test),
            callbacks=[ProgressCB()],
            verbose=0,
        )

        loss, accuracy = model.evaluate(X_test, y_test, verbose=0)
        print(f"   🎯 Accuracy: {accuracy:.4f}")

        # ── Convert to TFLite ──
        update_status(user_id, "UPLOADING_MODEL", 85)

        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_model = converter.convert()

        tflite_path = f"./model_{user_id[:8]}.tflite"
        with open(tflite_path, "wb") as f:
            f.write(tflite_model)

        label_map = {int(i): l for i, l in enumerate(label_encoder.classes_)}
        labels_path = f"./labels_{user_id[:8]}.json"
        with open(labels_path, "w") as f:
            json.dump(label_map, f, indent=2)

        # ── Cleanup Old Models (One Model Per User Policy) ──
        try:
            old_files = supabase.storage.from_(MODELS_BUCKET).list(user_id)
            files_to_delete = [f"{user_id}/{x['name']}" for x in old_files if x['name'].startswith('model_') or x['name'].startswith('labels_')]
            if files_to_delete:
                supabase.storage.from_(MODELS_BUCKET).remove(files_to_delete)
                print(f"      🗑️ Deleted {len(files_to_delete)} old model files")
        except:
            pass

        # ── Upload to Supabase ──
        # Use timestamp as version to ensure app always detects update
        next_version = int(datetime.utcnow().timestamp())

        model_remote = f"{user_id}/model_v{next_version}.tflite"
        with open(tflite_path, "rb") as f:
            supabase.storage.from_(MODELS_BUCKET).upload(
                model_remote, f.read(),
                file_options={"content-type": "application/octet-stream", "upsert": "true"}
            )

        labels_remote = f"{user_id}/labels_v{next_version}.json"
        with open(labels_path, "rb") as f:
            supabase.storage.from_(MODELS_BUCKET).upload(
                labels_remote, f.read(),
                file_options={"content-type": "application/octet-stream", "upsert": "true"}
            )

        supabase.table("trained_models").delete().eq("user_id", user_id).execute()

        supabase.table("trained_models").insert({
            "user_id": user_id,
            "trained_name_id": trained_names[0]["id"],
            "model_version": next_version,
            "model_path": model_remote,
            "training_sample_count": total_samples,
            "accuracy_metric": float(accuracy),
        }).execute()

        update_status(user_id, "COMPLETED", 100, model_version=next_version)

        print(f"   ✅ DONE — v{next_version} | {accuracy:.4f} acc | {os.path.getsize(tflite_path)/1024:.1f}KB")

        # Cleanup temp files
        os.remove(tflite_path)
        os.remove(labels_path)
        return True

    except Exception as e:
        error_msg = str(e)
        print(f"   ⛔ FAILED: {error_msg}")
        try:
            update_status(user_id, "FAILED", 0, error_message=error_msg)
        except:
            pass
        return False


# ═══════════════════════════════════════════════════
# 🚀 AUTO-DISCOVER & TRAIN ALL PENDING USERS
# ═══════════════════════════════════════════════════

# 🚀 AUTO-DISCOVER & TRAIN ALL PENDING USERS
print(f"\n{'='*50}")
print(" SCANNING FOR USERS (FORCE MODE ENABLED)")
print(f"{'='*50}")

try:
    # 0. Debug Check: Verify if we can see ANY data
    try:
        debug_check = supabase.table("audio_submissions").select("id", count="exact").limit(1).execute()
        print(f"DEBUG: Total rows visible in 'audio_submissions': {debug_check.count}")
        
        if debug_check.count == 0:
            print("\n⚠️ WARNING: 0 records found!")
            print("   Possible causes:")
            print("   1. You are using an ANON KEY. Use the SERVICE ROLE KEY to bypass RLS.")
            print("   2. No audio has been uploaded yet.")
            print("   3. You are connected to the wrong Supabase project.\n")
    except Exception as e:
        print(f"DEBUG: Failed to count rows: {e}")

    # 1. Get ALL users who have ever uploaded audio (ignore status)
    submissions = supabase.table("audio_submissions").select("user_id").execute()
    all_users = list(set(s["user_id"] for s in submissions.data))
    
    print(f"👉 Found {len(all_users)} unique users with audio.")

    users_to_train = []

    for uid in all_users:
        print(f"\n👤 Checking User: {uid}...")

        # 2. Get trained names
        names = supabase.table("trained_names").select("id, name_label").eq("user_id", uid).execute()
        
        if not names.data:
            print("   ⚠️ No names defined. Skipping.")
            continue
            
        print(f"   🏷️ Names: {[n['name_label'] for n in names.data]}")

        # 3. FORCE RESET STATUS
        # We delete the status row so the script treats this as a fresh start
        try:
            supabase.table("user_training_status").delete().eq("user_id", uid).execute()
            print("   ♻️ Cleared previous training status (Force Reset)")
        except:
            pass

        # 4. Add to training list unconditionally
        users_to_train.append({
            "user_id": uid, 
            "names": names.data, 
            "reason": "FORCE RETRAIN (NUCLEAR OPTION)"
        })

    if not users_to_train:
        print("\n❌ No valid users found to train.")
    else:
        print(f"\n🚀 STARTING TRAINING FOR {len(users_to_train)} USERS...\n")
        
        results = {"success": 0, "failed": 0} # Initialize results dictionary
        for user in users_to_train:
            success = train_user(user["user_id"], user["names"])
            if success:
                print(f"\n✅ SUCCESS: User {user['user_id']} model updated!")
                results["success"] += 1
            else:
                print(f"\n⛔ FAILURE: User {user['user_id']} training failed.")
                results["failed"] += 1

    # Cleanup dataset
    if os.path.exists(DATASET_DIR):
        shutil.rmtree(DATASET_DIR)

    print(f"\n{'=' * 50}")
    print(f"🏁 BATCH TRAINING COMPLETE")
    try:
        if 'results' in locals():
            print(f"   ✅ Success: {results['success']}")
            print(f"   ⛔ Failed:  {results['failed']}")
    except:
        pass
    print(f"{'=' * 50}")

except Exception as e:
    print(f"\n💥 CRITICAL ERROR IN MAIN LOOP: {e}")
    import traceback
    traceback.print_exc()
