#!/usr/bin/env -S dotnet fsi

open System
open System.IO
open System.Net.Http
open System.Net.Http.Headers
open System.Text

// Encapsulate everything in a function so "use" is allowed without warnings.
let runScript (args: string[]) =
    // Check arguments
    if args.Length < 1 then
        eprintfn "missing image filename (usage: ask-image.fsx <image> [prompt] [resp_type] [detail])"
        exit 1

    let imageFnm   = args.[0]
    let prompt     = if args.Length > 1 then args.[1] else "is there a bird looking at the camera?"
    let respType   = if args.Length > 2 then args.[2] else "boolean"
    let detail     = if args.Length > 3 then args.[3] else "low"

    // Make sure file exists
    if not (File.Exists imageFnm) then
        eprintfn $"File not found: {imageFnm}"
        exit 1

    // Validate the respType
    match respType with
    | "boolean" | "number" | "integer" | "string" -> ()
    | _ ->
        eprintfn $"resp_type param not one of boolean|number|integer|string: {respType}"
        exit 1

    // Read & base64-encode
    let jpgData = File.ReadAllBytes(imageFnm)
    let jpgB64  = Convert.ToBase64String jpgData

    // We'll just use "gpt-4o"
    let model = "gpt-4o"

    // Build JSON using string interpolation (F# 5.0+)
    let requestBody = $"""{{
    "model": "{model}",
    "store": false,
    "temperature": 0.0,
    "input": [
      {{
        "role": "user",
        "content": [
          {{"type": "input_text", "text": "{prompt}"}},
          {{
            "type": "input_image",
            "image_url": "data:image/jpeg;base64,{jpgB64}",
            "detail": "{detail}"
          }}
        ]
      }}
    ],
    "text": {{
      "format": {{
        "strict": true,
        "type": "json_schema",
        "name": "{respType}_response",
        "schema": {{
          "type": "object",
          "properties": {{
            "response": {{ "type": "{respType}" }}
          }},
          "required": ["response"],
          "additionalProperties": false
        }}
      }}
    }}
}}"""

    // Grab the API key from the environment
    let apiKey = Environment.GetEnvironmentVariable("OPENAI_API_KEY")
    if String.IsNullOrWhiteSpace(apiKey) then
        eprintfn "Warning: OPENAI_API_KEY is not set."

    // "use" within a function => no FS0524 warnings
    use client = new HttpClient()
    client.DefaultRequestHeaders.Authorization <- AuthenticationHeaderValue("Bearer", apiKey)

    use content = new StringContent(requestBody, Encoding.UTF8, "application/json")
    let response = client.PostAsync("https://api.openai.com/v1/responses", content).Result
    let body     = response.Content.ReadAsStringAsync().Result

    // Print response
    printfn "%s" body

// In an .fsx script, fsi.CommandLineArgs contains the script name as [0], so skip it:
let realArgs = fsi.CommandLineArgs |> Array.skip 1
runScript realArgs
