package com.zimbra.qa.soap;
import java.net.*;
import java.text.*;
import java.util.*;

/*
 * Source code is based on  http://java.sun.com/developer/JDCTechTips/2005/tt0913.html
 */


public class ZCookie {
	   

	     String name;
	     String value;
	     URI uri;
	     String domain;
	     Date expires;
	     String path;

	     private static DateFormat expiresFormat1
	        = new SimpleDateFormat("E, dd MMM yyyy k:m:s 'GMT'", Locale.US);
	     
	     
	     private static DateFormat expiresFormat2
	        = new SimpleDateFormat("E, dd-MMM-yyyy k:m:s 'GMT'", Locale.US);

	     private synchronized Date parseDateFormat(DateFormat format, String val) throws ParseException {
	    	 return format.parse(val);
	     }
			
	     public String getValue(){return value;}
	     /**
	      * Construct a cookie from the URI and header fields
	      *
	      * @param uri URI for cookie
	      * @param header Set of attributes in header
	      */
	     public ZCookie(URI uri, String header) {
	       String attributes[] = header.split(";");
	       String nameValue = attributes[0].trim();
	       this.uri = uri;
	       this.name = 
	         nameValue.substring(0, nameValue.indexOf('='));
	       this.value = 
	         nameValue.substring(nameValue.indexOf('=')+1);
	       this.path = "/";
	       this.domain = uri.getHost();

	       for (int i=1; i < attributes.length; i++) {
	         nameValue = attributes[i].trim();
	         int equals = nameValue.indexOf('=');
	         if (equals == -1) {
	           continue;
	         }
	         String name = nameValue.substring(0, equals);
	         String value = nameValue.substring(equals+1);
	         if (name.equalsIgnoreCase("domain")) {
	           String uriDomain = uri.getHost();
	           if (uriDomain.equals(value)) {
	             this.domain = value;
	           } else {
	             if (!value.startsWith(".")) {
	               value = "." + value;
	             }
	             uriDomain = uriDomain.substring(
	               uriDomain.indexOf('.'));
	             if (!uriDomain.equals(value)) {
	               throw new IllegalArgumentException(
	                 "Trying to set foreign cookie");
	             }
	             this.domain = value;
	           }
	         } else if (name.equalsIgnoreCase("path")) {
	           this.path = value;
	         } else if (name.equalsIgnoreCase("expires")) {
	           try {
	             this.expires = parseDateFormat(expiresFormat1, value);
	           } catch (ParseException e) {
	             try {
	               this.expires = parseDateFormat(expiresFormat2, value);
	             } catch (ParseException e2) {
	            		 throw new IllegalArgumentException("Bad date format in header: " + value); 
	     
	             }
	           }
	         }
	       }
	     }

	     public boolean hasExpired() {
	       if (expires == null) {
	         return false;
	       }
	       Date now = new Date();
	       return now.after(expires);
	     }

	     public String getName() {
	       return name;
	     }

	     public URI getURI() {
	       return uri;
	     }

	     /**
	      * Check if cookie isn't expired and if URI matches,
	      * should cookie be included in response.
	      *
	      * @param uri URI to check against
	      * @return true if match, false otherwise
	      */
	     public boolean matches(URI uri) {

	       if (hasExpired()) {
	         return false;
	       }

	      String path = uri.getPath();
	       if (path == null) {
	         path = "/";
	       }

	       
	       return (uri.getHost().contains(this.domain)  &&		   path.contains(this.path)); 
	    		   
	     }

	     public String toString() {
	       StringBuilder result = new StringBuilder(name);
	       result.append("=");
	       result.append(value);
	       return result.toString();
	     }
	   }
