package com.example;

import org.apache.commons.jelly.Jelly;
import org.apache.commons.jelly.JellyContext;
import org.apache.commons.jelly.Script;
import org.apache.commons.jelly.XMLOutput;
import org.apache.commons.jelly.JellyException;
import org.apache.commons.jelly.parser.XMLParser;
import org.xml.sax.SAXException;

import java.io.*;
import java.util.*;

public class Main {
    
    // Configuration
    private static final String JELLY_SCRIPT_DIR = "src/main/resources/jelly/";
    private static final String OUTPUT_DIR = "target/";
    
    public static void main(String[] args) {
        Main main = new Main();
        
        // Build all pages
        main.buildAllPages();
    }
    
    /**
     * Build all Jelly pages in the directory
     */
    public void buildAllPages() {
        System.out.println("🚀 Starting Jelly Page Builder");
        System.out.println("================================");
        
        File jellyDir = new File(JELLY_SCRIPT_DIR);
        
        // Check if directory exists
        if (!jellyDir.exists()) {
            System.err.println("❌ Directory not found: " + JELLY_SCRIPT_DIR);
            System.err.println("   Creating directory: " + jellyDir.getAbsolutePath());
            jellyDir.mkdirs();
            System.err.println("   Please add .jelly files to this directory and try again.");
            return;
        }
        
        File[] jellyFiles = jellyDir.listFiles((dir, name) -> name.endsWith(".jelly"));
        
        if (jellyFiles == null || jellyFiles.length == 0) {
            System.err.println("❌ No .jelly files found in " + JELLY_SCRIPT_DIR);
            System.err.println("   Please add .jelly files to: " + jellyDir.getAbsolutePath());
            return;
        }
        
        // Create output directory if it doesn't exist
        new File(OUTPUT_DIR).mkdirs();
        
        for (File jellyFile : jellyFiles) {
            try {
                buildPage(jellyFile);
            } catch (Exception e) {
                System.err.println("❌ Failed to build: " + jellyFile.getName());
                e.printStackTrace();
            }
        }
        
        System.out.println("\n✅ All pages built successfully!");
    }
    
    /**
     * Build a single Jelly page
     */
    private void buildPage(File jellyFile) throws IOException {
        String pageName = jellyFile.getName();
        String outputName = pageName.replace(".jelly", ".html");
        File outputFile = new File(OUTPUT_DIR + outputName);
        
        System.out.println("\n📄 Building: " + pageName + " → " + outputName);
        
        // Create Jelly context with common variables
        JellyContext context = createJellyContext(pageName);
        
        // Create output stream
        try (FileOutputStream fos = new FileOutputStream(outputFile);
             OutputStreamWriter writer = new OutputStreamWriter(fos, "UTF-8");
             FileReader reader = new FileReader(jellyFile)) {
            
            // Create XML output
            XMLOutput xmlOutput = XMLOutput.createXMLOutput(writer);
            
            // Load and run the script
            long startTime = System.currentTimeMillis();
            
            try {
                // Use XMLParser to parse the script
                XMLParser parser = new XMLParser();
                parser.setContext(context);
                
                // Parse the Jelly file into a Script
                Script script = parser.parse(reader);
                
                // Run the script
                script.run(context, xmlOutput);
                
            } catch (SAXException e) {
                throw new IOException("Failed to parse Jelly script: " + e.getMessage(), e);
            } catch (JellyException e) {
                throw new IOException("Failed to execute Jelly script: " + e.getMessage(), e);
            }
            
            long endTime = System.currentTimeMillis();
            
            xmlOutput.flush();
            
            System.out.println("   ✅ Built in " + (endTime - startTime) + "ms");
            System.out.println("   📍 Output: " + outputFile.getAbsolutePath());
        }
    }
    
    /**
     * Create Jelly context with common variables
     */
    private JellyContext createJellyContext(String currentPage) {
        JellyContext context = new JellyContext();
        
        // Add global variables available to all pages
        context.setVariable("appName", "My Jelly Application");
        context.setVariable("version", "1.0.0");
        context.setVariable("buildDate", new Date().toString());
        context.setVariable("currentPage", currentPage);
        
        // Add system properties
        context.setVariable("javaVersion", System.getProperty("java.version"));
        context.setVariable("osName", System.getProperty("os.name"));
        
        // Add custom objects
        context.setVariable("helper", new JellyHelper());
        
        // Add timestamp
        context.setVariable("timestamp", System.currentTimeMillis());
        
        return context;
    }
    
    /**
     * Helper class with utility methods for Jelly scripts
     */
    public static class JellyHelper {
        
        public String formatDate(Date date, String pattern) {
            return new java.text.SimpleDateFormat(pattern).format(date);
        }
        
        public String uppercase(String str) {
            return str != null ? str.toUpperCase() : "";
        }
        
        public String lowercase(String str) {
            return str != null ? str.toLowerCase() : "";
        }
        
        public boolean isEven(int number) {
            return number % 2 == 0;
        }
        
        public String getCurrentTime() {
            return new Date().toString();
        }
    }
}