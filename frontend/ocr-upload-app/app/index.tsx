import axios from 'axios';
import * as ImagePicker from 'expo-image-picker';
import React, { useState } from 'react';
import { ActivityIndicator, Button, Image, ScrollView, StyleSheet, Text, View } from 'react-native';

export default function App() {
  const [imageUri, setImageUri] = useState<string | null>(null);
  const [ocrText, setOcrText] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);

  const backendUrl = "https://your-render-backend.onrender.com/ocr/"; // Replace this!

  const pickImage = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: [ImagePicker.MediaType.IMAGE],
      quality: 1,
    });

    if (!result.canceled && result.assets?.length) {
      const selectedAsset = result.assets[0];
      if (selectedAsset.uri) {
        setImageUri(selectedAsset.uri);
        uploadToBackend(selectedAsset.uri);
      }
    }
  };

  const uploadToBackend = async (uri: string) => {
    try {
      setLoading(true);
      setOcrText('');

      const formData = new FormData();
      formData.append('file', {
        uri,
        name: 'image.jpg',
        type: 'image/jpeg',
      } as any);

      const response = await axios.post(backendUrl, formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });

      setOcrText(response.data.text);
    } catch (error) {
      console.error("Upload error:", error);
      setOcrText("Error during OCR.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>📄 OCR Upload App</Text>

      <Button title="Pick Image for OCR" onPress={pickImage} />

      {imageUri && <Image source={{ uri: imageUri }} style={styles.image} />}

      {loading && <ActivityIndicator size="large" />}

      {ocrText ? (
        <View style={styles.textBox}>
          <Text style={{ fontWeight: 'bold' }}>Extracted Text:</Text>
          <Text>{ocrText}</Text>
        </View>
      ) : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    padding: 20,
    alignItems: 'center',
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  image: {
    width: 300,
    height: 300,
    marginVertical: 20,
  },
  textBox: {
    marginTop: 20,
    padding: 15,
    backgroundColor: '#f6f6f6',
    borderRadius: 10,
    width: '100%',
  },
});
