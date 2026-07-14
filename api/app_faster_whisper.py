# Copyright 2025 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# REST API for transcription server based on faster-whisper.
# This also supports word-level probabilities to be returned as well as running a VAD to avoid
# hallucinations when there is no speech present.
# 
# Parameters:
# - add_word_probabilities to add the word-level probabilities
# - run_vad_filter for the Voice Activity Detector
# Note: turning these on will make processing slower!

from faster_whisper import WhisperModel
from flask import Flask, Response, request
import io
import os
import tempfile
import shutil

# this can either download one of the existing converted whisper models:
# NOTE: mantido "tiny" para caber no plano App Service F1 (Free, ~1GB RAM).
# "small" causaria OOM no F1; usar tiny evita derrubar o serviço.
faster_whisper_model_name_or_path = "tiny" 
# # or you can specify a custom converted model (relative path), eg:
# faster_whisper_model_name_or_path = "my_converted_model_path"
# # to convert a model use this script
# ct2-transformers-converter \
#     --model /path/to/model/checkpoint-2000 \
#     --output_dir /tmp/my_converted_model_path \
#     --quantization int8

# Lazy load model to avoid blocking startup (health check timeout)
whisper_model = None

def get_model():
    global whisper_model
    if whisper_model is None:
        whisper_model = WhisperModel(faster_whisper_model_name_or_path, device="cpu", compute_type="int8")
    return whisper_model

BEAM_SIZE = 5 # could set to 1 for faster processing, but that will come at decreased quality most likely
LANGUAGE = 'pt' # when no language is set, model will predict the languages (this is discuraged for our use as it makes processing slower)

app = Flask(__name__)

@app.route('/')
def health():
    return Response("OK", status=200)

@app.route('/transcribe', methods=['POST'])
def transcribe():
    # test with:
    #  - curl -F wav=@/path/to/16khz.wav "http://localhost:8080/transcribe"
    #  - curl -F wwav=@/path/to/16khz.wav "http://localhost:8080/transcribe?add_word_probabilities=true&run_vad_filter=true"
    
    # store uploaded file temporarily for processing
    _, tmp_wav_file = tempfile.mkstemp()
    audio = request.files['wav']
    add_word_probabilities = request.args.get('add_word_probabilities', default='False').lower() == 'true'
    run_vad_filter = request.args.get('run_vad_filter', default='False').lower() == 'true'

    # Note: we are expecting mono 16khz audios (can extend to convert if needed)
    # if not audio.filename.endswith('.wav'):
    #     return {"response": "invalid file, must be WAV"}
    audio.save(dst=tmp_wav_file)
    print('>> Successfully uploaded audio file %s to %s' %(audio.filename, tmp_wav_file))    
    
    # transcribe
    segments, info = get_model().transcribe(
        tmp_wav_file,
        condition_on_previous_text=False, # this seems to reduce hallucinations, but might also not matter for our short transcripts
        language=LANGUAGE, 
        beam_size=BEAM_SIZE,
        word_timestamps=add_word_probabilities,
        vad_filter=run_vad_filter)
    if not LANGUAGE:
        print("Detected language '%s' with probability %f" % (info.language, info.language_probability))

    pred = ''
    for segment in segments:
        if add_word_probabilities:
            # if we have word timestamps, add probability to word (assuming the UI will filter this out)
            for word in segment.words:
                print(word.word, word.probability, word.start,word.end)
                pred += word.word + '/' + str(word.probability) + ' '
        else:
            # otherwise just use the whole segment text
            print("[%.2fs -> %.2fs] %s" % (segment.start, segment.end, segment.text))
            pred += segment.text + ' '
    pred = pred.strip()

    # remove file and copy
    os.remove(tmp_wav_file)    
    return {"response": "success!", "transcript": pred}


if __name__ == '__main__':
    app.run(debug=True, host='127.0.0.1', port=8080)
