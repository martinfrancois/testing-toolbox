export async function callBackend() {
    const response = await fetch('http://localhost:3000/test');
    const data = await response.json();
    return data;
}

