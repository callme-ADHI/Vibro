# VIBRO Google Colab Training Pipeline

This directory contains Google Colab notebooks and scripts for training voice detection models.

## 📁 Structure

```
colab/
├── README.md                    # This file
├── training_pipeline.ipynb      # Main training notebook
├── requirements.txt             # Python dependencies
└── utils/                       # Helper scripts
    ├── supabase_client.py      # Supabase integration
    ├── audio_processor.py      # Audio preprocessing
    └── model_trainer.py        # TFLite model training
```

## 🎯 Purpose

Train personalized voice detection models using audio submissions from users and deploy them back to Supabase storage.

## 🚀 Workflow

1. **Poll Training Queue** - Get next pending training job from Supabase
2. **Download Audio** - Fetch audio clips from Supabase Storage
3. **Preprocess** - Convert to spectrograms, augment data
4. **Train Model** - Train TFLite model for edge deployment
5. **Upload Model** - Save to Supabase Storage
6. **Update Status** - Mark training as complete

## 🔑 Environment Variables

Create a `.env` file or use Colab secrets:

```
SUPABASE_URL=https://pqtjvdfcitdpveuqzgpk.supabase.co
SUPABASE_SERVICE_KEY=your_service_role_key_here
```

**⚠️ Never use anon key - use service role key for Colab!**

## 📊 Supabase Integration

The pipeline interacts with:
- `training_queue` - Job management
- `audio_submissions` - Training data metadata
- `trained_models` - Model versioning
- Storage: `audio_uploads/` - Input audio
- Storage: `trained_models/` - Output models

## 🧪 Quick Start

1. Upload notebook to Google Colab
2. Set environment variables
3. Run all cells
4. Monitor training queue

## 📝 Notes

- Models are optimized for ESP32 deployment
- Training uses transfer learning for efficiency
- Automatic versioning for each trained name
- Supports audio augmentation for better accuracy

---

**Status:** 🚧 Under Development
**Last Updated:** 2026-02-13
