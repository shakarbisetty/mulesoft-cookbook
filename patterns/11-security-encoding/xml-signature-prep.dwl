/**
 * Pattern: XML Signature Preparation
 * Category: Security & Encoding
 * Difficulty: Advanced
 *
 * Description: Prepare XML for WS-Security signing by canonicalizing
 * elements, stripping whitespace, and building the SignedInfo reference
 * structure. Used in SOAP integrations with banks, government APIs,
 * and enterprise B2B services.
 *
 * Input (application/xml):
 * <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
 *   <soap:Header/>
 *   <soap:Body>
 *     <Order xmlns="http://example.com/orders">
 *       <OrderId>ORD-001</OrderId>
 *       <Amount currency="USD">1500.00</Amount>
 *       <Customer>Acme Corp</Customer>
 *     </Order>
 *   </soap:Body>
 * </soap:Envelope>
 *
 * Output (application/xml):
 * <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
 *   <soap:Header>
 *     <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
 *       <ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
 *         <ds:SignedInfo>
 *           <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
 *           <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
 *           <ds:Reference URI="#body">
 *             <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
 *             <ds:DigestValue><!-- computed digest --></ds:DigestValue>
 *           </ds:Reference>
 *         </ds:SignedInfo>
 *       </ds:Signature>
 *     </wsse:Security>
 *   </soap:Header>
 *   <soap:Body Id="body">
 *     <Order xmlns="http://example.com/orders">
 *       <OrderId>ORD-001</OrderId>
 *       <Amount currency="USD">1500.00</Amount>
 *       <Customer>Acme Corp</Customer>
 *     </Order>
 *   </soap:Body>
 * </soap:Envelope>
 */
%dw 2.0
import dw::Crypto
output application/xml

ns soap http://schemas.xmlsoap.org/soap/envelope/
ns wsse http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd
ns ds http://www.w3.org/2000/09/xmldsig#
ns ord http://example.com/orders

// Canonicalize the body content for digest computation
var bodyContent = write(payload.soap#Envelope.soap#Body, "application/xml",
    {indent: false, writeDeclaration: false})
var bodyDigest = Crypto::hashWith(bodyContent as Binary {encoding: "UTF-8"}, "SHA-256")
---
{
    soap#Envelope: {
        soap#Header: {
            wsse#Security: {
                ds#Signature: {
                    ds#SignedInfo: {
                        ds#CanonicalizationMethod @(Algorithm: "http://www.w3.org/2001/10/xml-exc-c14n#"): "",
                        ds#SignatureMethod @(Algorithm: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"): "",
                        ds#Reference @(URI: "#body"): {
                            ds#DigestMethod @(Algorithm: "http://www.w3.org/2001/04/xmlenc#sha256"): "",
                            ds#DigestValue: bodyDigest
                        }
                    }
                }
            }
        },
        soap#Body @(Id: "body"): payload.soap#Envelope.soap#Body
    }
}

// Note: Actual WS-Security signing requires the private key operation
// which should be done in a MuleSoft WS-Security policy or Java component.
// This pattern builds the structure; signing happens at the transport layer.
