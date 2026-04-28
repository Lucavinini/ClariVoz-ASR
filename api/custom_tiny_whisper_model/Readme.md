# Configuracao do modelo

Coloque o modelo custom tiny whisper no diretorio custom_tiny_whisper_model como pytorch_model.bin.

Voce pode salvar seu modelo whisper customizado com:

```python
whisper_model.save_pretrained(<PATH>, safe_serialization=False)
```
