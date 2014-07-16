package org.giswater.util;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.SocketException;
import java.net.URL;

import org.apache.commons.net.ftp.FTP;
import org.apache.commons.net.ftp.FTPClient;
import org.apache.commons.net.ftp.FTPFile;
import org.apache.commons.net.ftp.FTPReply;


public class UtilsFTP {

	public FTPClient client;
    private final String host;
    private final int port;
    private final String username;
    private final String password;
	private InputStream inputStream;
    private String ftpVersion;   // FTP last version 
    
    private final String FTP_HOST = "ftp://download.giswater.org";
    private final String FTP_USER = "giswaterdownro";
    private final String FTP_PWD = "9kuKZCEaquwM6X7jAmuaMg==";
    private final String FTP_ROOT_FOLDER = "htdocs";
	private String newMinorVersion;
	private String newBuildVersion;
	private String newMinorVersionFolder;
    

	public UtilsFTP () {
		
        URL url = null;
        try {
            url = new URL(FTP_HOST);
        } catch (MalformedURLException e) {
            Utils.logError(e);
        }
        this.host = url != null ? url.getHost() : null;
		this.port = 0;
        this.username = FTP_USER;
        this.password = Encryption.decrypt(FTP_PWD);
		
	}
	
    
    public boolean connect() {
    	
    	boolean ok = false;
        if (client == null) {
            client = new FTPClient();
        }
        
        try {
            // Connecting client
            if (port > 0) {
                client.connect(host, port);
            } else {
                client.connect(host);
            }

            // Check connection
            int reply = client.getReplyCode();
            if (!FTPReply.isPositiveCompletion(reply)) {
                disconnect();
            } else {
                setFtpOptions();
                ok = true;
            }
        } catch (SocketException e) {
        	Utils.logError(e);
            disconnect();
        } catch (IOException e) {
        	Utils.logError(e);
            disconnect();
        }
        
        return ok;
        
    }

    
    public void disconnect () {
    	
        if (client != null) {
            if (client.isConnected()) {
                try {
                    client.disconnect();
                } catch (IOException e) {
                	Utils.logError(e);
                }
            } else {
            	Utils.logError("client disconnected");
            }
        } 
        
    }

    
    public boolean login () {
    	
        if (isConnected()) {
            try {
                boolean ok = client.login(username, password);
                return ok;
            } catch (Exception e) {
            	Utils.logError(e);
                logout();
                return false;
            }
        }
		throw new IllegalStateException("Client disconnected");
		
    }

    
    public void store(String filename, FileInputStream fis) throws IOException {
    	this.client.storeFile(filename, fis);    	
    }
    
    
    public boolean logout () {
    	
        if (isConnected()) {
            try {
                return this.client.logout();
            } catch (IOException e) {
            	Utils.logError(e);
                return false;
            }
        }
		throw new IllegalStateException("Client disconnected");
		
    }

    
    public FTPFile[] listDirectories () {
    	
        if (isConnected()) {
            try {
                return this.client.listDirectories();
            } catch (IOException e) {
            	Utils.logError(e);
                return null;
            }
        }
		throw new IllegalStateException("Client disconnected");
		
    }

    
    public FTPFile[] listFiles() {
    	
        if (isConnected()) {
            try {
                return this.client.listFiles();
            } catch (IOException e) {
            	Utils.logError(e);
                return null;
            }
        }
		throw new IllegalStateException("Client disconnected");
		
    }
    
    
    public boolean isConnected () {
        if (client != null) {
            return client.isConnected();
        }
		return false;
    }
    

    private void setFtpOptions () {
        if (isConnected()) {
            client.enterLocalPassiveMode();
        }
    }

    
    public long getFileSize(String filePath) {
    	
    	long size = -1;
        try {
        	changeDirectory();
        	FTPFile[] ftpFile = client.listFiles(filePath);
	        if (ftpFile.length > 0){
	        	size = ftpFile[0].getSize();
	        }
	        else{
	        	Utils.showError("Downloaded aborted. File not found in FTP server:\n"+filePath);
	        }
        } catch (IOException ex) {
        	Utils.logError("Could not determine size of the file: " + ex.getMessage());
        }
        return size;
        
    }
    
     
	public String getFtpVersion() {
		return ftpVersion;
	}
	
	
	public boolean prepareConnection(){
		
		if (!isConnected()){
	        if (!connect()){
	        	Utils.logError("FTP host not valid. Check FTP parameters defined in config.properties file");
	        	return false;
	        }
	        if (!login()){
	        	Utils.logError("FTP user or password not valid. Check FTP parameters defined in config.properties file");
	        	return false;
	        }
		}
		return true;
		
	}
	
	
	public void changeDirectory() {
		
    	try {
			client.changeWorkingDirectory(FTP_ROOT_FOLDER);
			client.changeWorkingDirectory(newMinorVersionFolder);
			client.changeWorkingDirectory(newBuildVersion);
		} catch (IOException e) {
			Utils.logError(e);
		}
    	
	}
	

	public boolean checkVersion(Integer majorVersion, Integer minorVersion, Integer buildVersion) {
		
		if (!prepareConnection()){
			return false;
		}
		
		boolean updateMinorVersion = false;
        boolean updateVersion = false;
		try {
			// Get last minor version available in root folder
	        client.changeWorkingDirectory(FTP_ROOT_FOLDER);
	        String currentMinorVersion = "versions_"+majorVersion+"."+minorVersion;
	        updateMinorVersion = checkMinorVersion(currentMinorVersion);
	        if (!updateMinorVersion){
	        	newMinorVersionFolder = "versions_"+majorVersion+"."+minorVersion;
	        	newMinorVersion = minorVersion.toString();
	        }
	        // Get last build version available of the last minor version folders
        	client.changeWorkingDirectory(newMinorVersionFolder);
        	updateVersion = checkBuildVersion(majorVersion, buildVersion);
		} catch (NumberFormatException | IOException e) {
			Utils.logError(e);
		}

        logout();
        disconnect();
        
        return updateMinorVersion || updateVersion;
		
	}

	
	private boolean checkMinorVersion(String currentMinorVersion) {
		
        boolean updateMinorVersion = false;
        FTPFile[] listFolders = listDirectories();
        FTPFile folder = listFolders[listFolders.length-1];
        newMinorVersionFolder = folder.getName().trim().toLowerCase();
        newMinorVersion = newMinorVersionFolder.substring(newMinorVersionFolder.length() - 1);
        Utils.getLogger().info("FTP last minor version folder name: "+newMinorVersionFolder);
        if (!currentMinorVersion.equals("newMinorVersion")){
        	updateMinorVersion = true;
        }
        return updateMinorVersion;
		
	}
	

	private boolean checkBuildVersion(Integer majorVersion, Integer buildVersion) {
		
        boolean updateVersion = false;
        FTPFile[] listFolders = listDirectories();
        FTPFile folder = listFolders[listFolders.length-1];
        newBuildVersion = folder.getName();
        ftpVersion = majorVersion+"."+newMinorVersion+"."+newBuildVersion;
        Utils.getLogger().info("FTP last version code: "+ftpVersion);
        Integer version = Integer.parseInt(folder.getName());
        if (version > buildVersion){
        	updateVersion = true;
        }
        return updateVersion;
		
	}


	public boolean downloadLastVersion(String remoteName, String localPath) {
		
		if (!prepareConnection()){
			return false;
		}

		try {
			changeDirectory();
	        FTPFile[] ftpFile = client.listFiles(remoteName);
	        if (ftpFile.length > 0){
	            FileOutputStream fos = new FileOutputStream(localPath);		
				client.retrieveFile(remoteName, fos);
	        }
	        else{
	        	Utils.showError("Downloaded aborted. File not found in FTP server:\n"+remoteName);
	        	return false;
	        }
		} catch (IOException e) {
			Utils.logError(e);
		}

        logout();
        disconnect();
        
        return true;
		
	}
	
	
    public boolean downloadFile(String downloadPath) {
    	
    	boolean status = false;
        try {
     		if (!prepareConnection()){
    			return false;
    		}
            boolean success = client.setFileType(FTP.BINARY_FILE_TYPE);
            if (!success) {
            	Utils.showError("Could not set binary file type.");
            }
            inputStream = client.retrieveFileStream(downloadPath);
            if (inputStream == null) {
            	Utils.showError("Could not open input stream. The file may not exist on the server.");
            }
        } catch (IOException ex) {
        	Utils.showError("Error downloading file: " + ex.getMessage());
        }
        
        status = true;
        return status;
        
    }
    
    
    public void finish() throws IOException {
        inputStream.close();
        client.completePendingCommand();
    }
    
    
    public InputStream getInputStream() {
        return inputStream;
    }
    
        
}