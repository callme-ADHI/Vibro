# ═══════════════════════════════════════════════════
# 🔷 VIBRO — Manual Training Pipeline (Single Script)
# ═══════════════════════════════════════════════════
# INSTRUCTIONS:
#   1. Open Google Colab (colab.research.google.com)
#   2. Go to Runtime → Change runtime type → GPU
#   3. Create a new cell, paste ALL of this code
#   4. Fill in SUPABASE_SERVICE_ROLE_KEY and USER_ID below
#   5. Click Run (▶)
# ═══════════════════════════════════════════════════

# ──── STEP 0: Install dependencies ────
import subprocess
subprocess.check_call(["pip", "install", "-q", "supabase", "tensorflow", "librosa", "scikit-learn", "numpy"])

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
# ⚠️  FILL THESE IN — DO NOT SHARE / COMMIT
# ═══════════════════════════════════════════════════

SUPABASE_URL = "https://pqtjvdfcitdpveuqzgpk.supabase.co"
SUPABASE_SERVICE_ROLE_KEY = ""   # ← Paste your service role key
USER_ID = ""                     # ← Paste the user's UUID

# ═══════════════════════════════════════════════════

assert SUPABASE_SERVICE_ROLE_KEY, "⛔ Paste your SUPABASE_SERVICE_ROLE_KEY above"
assert USER_ID, "⛔ Paste the USER_ID above"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

AUDIO_BUCKET = "audio_submissions"
MODELS_BUCKET = "trained_models"
SAMPLE_RATE = 16000
N_MFCC = 40
MAX_PAD_LEN = 64
DATASET_DIR = "./dataset"

print(f"✅ Connected | User: {USER_ID[:8]}...")


# ──── HELPER: Update training status ────
def update_status(status, progress, error_message=None, model_version=None):
    data = {
        "status": status,
        "progress_percentage": progress,
        "updated_at": datetime.utcnow().isoformat(),
    }
    if error_message is not None:
        data["error_message"] = error_message
    if model_version is not None:
        data["model_version"] = model_version

    existing = supabase.table("user_training_status").select("id").eq("user_id", USER_ID).execute()
    if existing.data:
        supabase.table("user_training_status").update(data).eq("user_id", USER_ID).execute()
    else:
        data["user_id"] = USER_ID
        names = supabase.table("trained_names").select("id").eq("user_id", USER_ID).limit(1).execute()
        if names.data:
            data["trained_name_id"] = names.data[0]["id"]
        supabase.table("user_training_status").insert(data).execute()
    print(f"📊 {status} | {progress}%")


# ═════════════════════════════════════════
# STEP 1: DOWNLOAD AUDIO
# ═════════════════════════════════════════
try:
    update_status("DOWNLOADING_AUDIO", 10)

    names_resp = supabase.table("trained_names").select("id, name_label").eq("user_id", USER_ID).execute()
    trained_names = names_resp.data
    assert trained_names, "⛔ No trained names found for this user"

    print(f"\n📋 Found {len(trained_names)} names:")
    for n in trained_names:
        print(f"   • {n['name_label']}")

    if os.path.exists(DATASET_DIR):
        shutil.rmtree(DATASET_DIR)

    total_samples = 0
    for entry in trained_names:
        name_id, label = entry["id"], entry["name_label"]
        name_dir = os.path.join(DATASET_DIR, label)
        os.makedirs(name_dir, exist_ok=True)

        storage_path = f"{USER_ID}/{name_id}"
        try:
            files = supabase.storage.from_(AUDIO_BUCKET).list(storage_path)
        except Exception as e:
            print(f"   ⚠️  {label}: {e}")
            continue

        wav_files = [f for f in files if f["name"].endswith(".wav")]
        for wav in wav_files:
            try:
                data = supabase.storage.from_(AUDIO_BUCKET).download(f"{storage_path}/{wav['name']}")
                with open(os.path.join(name_dir, wav["name"]), "wb") as f:
                    f.write(data)
                total_samples += 1
            except Exception as e:
                print(f"   ⚠️  {wav['name']}: {e}")

        print(f"   ✅ {label}: {len(wav_files)} samples")

    assert total_samples > 0, "⛔ No audio samples downloaded"
    print(f"\n📦 Total: {total_samples} samples")
    update_status("DOWNLOADING_AUDIO", 30)

    # ═════════════════════════════════════════
    # STEP 2: FEATURE EXTRACTION (MFCC)
    # ═════════════════════════════════════════
    def extract_mfcc(file_path):
        try:
            audio, _ = librosa.load(file_path, sr=SAMPLE_RATE)
            mfcc = librosa.feature.mfcc(y=audio, sr=SAMPLE_RATE, n_mfcc=N_MFCC)
            if mfcc.shape[1] < MAX_PAD_LEN:
                mfcc = np.pad(mfcc, ((0, 0), (0, MAX_PAD_LEN - mfcc.shape[1])), mode='constant')
            else:
                mfcc = mfcc[:, :MAX_PAD_LEN]
            return mfcc
        except Exception as e:
            print(f"   ⚠️  {file_path}: {e}")
            return None

    features, labels = [], []
    for entry in trained_names:
        name_dir = os.path.join(DATASET_DIR, entry["name_label"])
        if not os.path.exists(name_dir):
            continue
        for wav in sorted(os.listdir(name_dir)):
            if not wav.endswith(".wav"):
                continue
            mfcc = extract_mfcc(os.path.join(name_dir, wav))
            if mfcc is not None:
                features.append(mfcc)
                labels.append(entry["name_label"])

    X = np.array(features)
    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(labels)
    num_classes = len(label_encoder.classes_)

    X = X / np.max(np.abs(X))
    X_flat = X.reshape(X.shape[0], -1)
    X_train, X_test, y_train, y_test = train_test_split(
        X_flat, y, test_size=0.2, random_state=42, stratify=y
    )

    print(f"\n🔬 Features: {X.shape} | Classes: {list(label_encoder.classes_)}")
    print(f"   Train: {len(X_train)} | Test: {len(X_test)}")
    update_status("TRAINING", 40)

    # ═════════════════════════════════════════
    # STEP 3: TRAIN MODEL
    # ═════════════════════════════════════════
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(X_flat.shape[1],)),
        tf.keras.layers.Dense(256, activation='relu'),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(num_classes, activation='softmax'),
    ])
    model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])
    model.summary()

    EPOCHS = 50

    class ProgressCallback(tf.keras.callbacks.Callback):
        def on_epoch_end(self, epoch, logs=None):
            progress = 40 + int((epoch + 1) / EPOCHS * 40)
            acc = logs.get('accuracy', 0)
            val_acc = logs.get('val_accuracy', 0)
            print(f"   Epoch {epoch+1}/{EPOCHS} — acc: {acc:.4f} | val_acc: {val_acc:.4f}")
            if (epoch + 1) % 5 == 0 or (epoch + 1) == EPOCHS:
                try:
                    update_status("TRAINING", min(progress, 80))
                except:
                    pass

    history = model.fit(
        X_train, y_train,
        epochs=EPOCHS, batch_size=16,
        validation_data=(X_test, y_test),
        callbacks=[ProgressCallback()],
        verbose=0,
    )

    loss, accuracy = model.evaluate(X_test, y_test, verbose=0)
    print(f"\n🎯 Accuracy: {accuracy:.4f} | Loss: {loss:.4f}")

    # ═════════════════════════════════════════
    # STEP 4: CONVERT TO TFLITE
    # ═════════════════════════════════════════
    update_status("UPLOADING_MODEL", 85)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    TFLITE_PATH = "./vibro_model.tflite"
    with open(TFLITE_PATH, "wb") as f:
        f.write(tflite_model)
    print(f"✅ TFLite: {os.path.getsize(TFLITE_PATH) / 1024:.1f} KB")

    label_map = {int(i): l for i, l in enumerate(label_encoder.classes_)}
    LABELS_PATH = "./label_mapping.json"
    with open(LABELS_PATH, "w") as f:
        json.dump(label_map, f, indent=2)
    print(f"✅ Labels: {label_map}")

    # ═════════════════════════════════════════
    # STEP 5: UPLOAD TO SUPABASE
    # ═════════════════════════════════════════
    existing_models = supabase.table("trained_models") \
        .select("model_version") \
        .eq("user_id", USER_ID) \
        .order("model_version", desc=True) \
        .limit(1).execute()

    next_version = (existing_models.data[0]["model_version"] + 1) if existing_models.data else 1
    print(f"📦 Version: v{next_version}")

    # Upload model
    model_path = f"{USER_ID}/model_v{next_version}.tflite"
    with open(TFLITE_PATH, "rb") as f:
        supabase.storage.from_(MODELS_BUCKET).upload(
            model_path, f.read(),
            file_options={"content-type": "application/octet-stream", "upsert": "true"}
        )

    # Upload labels
    labels_path = f"{USER_ID}/labels_v{next_version}.json"
    with open(LABELS_PATH, "rb") as f:
        supabase.storage.from_(MODELS_BUCKET).upload(
            labels_path, f.read(),
            file_options={"content-type": "application/octet-stream", "upsert": "true"}
        )

    # Insert DB record
    first_name_id = trained_names[0]["id"]
    supabase.table("trained_models").insert({
        "user_id": USER_ID,
        "trained_name_id": first_name_id,
        "model_version": next_version,
        "model_path": model_path,
        "training_sample_count": total_samples,
        "accuracy_metric": float(accuracy),
    }).execute()

    update_status("COMPLETED", 100, model_version=next_version)

    print(f"\n{'═' * 40}")
    print(f"🎉 TRAINING COMPLETE")
    print(f"   User:     {USER_ID[:8]}...")
    print(f"   Version:  v{next_version}")
    print(f"   Accuracy: {accuracy:.4f}")
    print(f"   Names:    {list(label_encoder.classes_)}")
    print(f"{'═' * 40}")

except Exception as e:
    error_msg = str(e)
    print(f"\n⛔ FAILED: {error_msg}")
    try:
        update_status("FAILED", 0, error_message=error_msg)
    except:
        print("⚠️  Could not update failure status")
