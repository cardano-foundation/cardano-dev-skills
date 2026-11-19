---
description: How to register as a DRep
---

# Register as a DRep

1.  **Dashboard**\
    From the dashboard, click "Register" in the "Become a DRep" panel:


    <div align="left"><figure><img src="/img/gitbook/Artboard%20Copy%201000.webp" alt=""><figcaption></figcaption></figure></div>
2.  **Roles and Responsibilities**\
    The "Roles & Responsibilities" screen explains what a DRep does, and tells you about the refundable deposit (the amount comes from the `drepDeposit` protocol parameter). If you previously retired as a DRep, this step is skipped.


    <div align="left"><figure><img src="/img/gitbook/drep%20reg%202.webp" alt=""><figcaption></figcaption></figure></div>
3.  **DRep Info**\
    The form follows the [CIP-119](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0119) DRep metadata standard. **DRep Name** is required (max 80 characters). All other fields are optional:

    * **Objectives**, **Motivations** and **Qualifications** (max 1,000 characters each)
    * **Image**: a URL to an image, or a base64-encoded image
    * **References**: **Links** (social media or other web pages) and **Identity** links (ideally a page that clearly shows your DRep ID). Up to 7 of each; each description is limited to 80 characters.
    * **Payment Address**: an address for receiving payments
    * **Do Not List**: tick this if you don't want to appear in the GovTool DRep Directory

    This information will be displayed on your DRep page, and is publicly available to all users of GovTool.
4.  **Data storage confirmation**\
    DRep data is not stored on-chain. Every DRep must responsibly store their information off-chain and pass that link back to GovTool (on the following screen). You must check the box "I agree to store correctly this information and to maintain them over the years" and click "Register" to proceed.


    <div align="left"><figure><img src="/img/gitbook/drep%20reg%204.webp" alt=""><figcaption></figcaption></figure></div>
5. **Storing your information**\
   There are three steps to storing your information:
   1. Download the file to your computer. This file contains the DRep registration info that you entered in the registration form.
   2. Save the file in a location that will provide you with a publicly-accessible URL.
   3. Copy the URL from the location above and paste it into the URL field. The URL must start with `https://` or `ipfs://` and be no longer than 128 characters.

   When you click "Submit", GovTool downloads the file from your URL and checks that it is identical to the one you downloaded ("GovTool Is Checking Your Data"). If the URL can't be found ("The URL You Entered Cannot Be Found") or the content differs ("Your External Data Does Not Match the Original File."), you'll be asked to fix it before continuing.
6.  **Example using GitHub** [**See example using IPFS**](./register-as-a-drep.md#ipfs)\
    \
    This example uses a new public repo for simplicity.&#x20;

    1. Upload the file you downloaded in the step above to GitHub&#x20;
    2. Commit the changes to the repository with the green button at the bottom right

    <figure><img src="/img/gitbook/github%201%20%281%29.webp" alt=""><figcaption></figcaption></figure>
7.  **In GitHub, find the file you uploaded, click on it's name.**


    <figure><img src="/img/gitbook/github%202.webp" alt=""><figcaption></figcaption></figure>
8.  **In Code view, click on the "Raw" button**\
    This will take you to the 'Raw' view where you can copy the URL for the code&#x20;

    <figure><img src="/img/gitbook/github%203.webp" alt=""><figcaption></figcaption></figure>
9.  **In the Raw view, click on the URL in the top bar and copy it**

    <figure><img src="/img/gitbook/github%204%20%281%29.webp" alt=""><figcaption></figcaption></figure>
10. **Return to GovTool and paste in the URL** \
    Then click "Submit"


    <figure><img src="/img/gitbook/drep%20reg%206.webp" alt=""><figcaption></figcaption></figure>
11. **Sign the transaction in your wallet**\
    &#x20;

    <figure><img src="/img/gitbook/drep%20reg%207.webp" alt=""><figcaption></figcaption></figure>
12. **Your transaction will be submitted to the blockchain**


    <figure><img src="/img/gitbook/drep%20reg%208.webp" alt=""><figcaption></figcaption></figure>
13. **Now you are registered as a DRep**\
    The registration transaction also delegates your own Voting Power to your new DRep ID, and registers your stake key if it wasn't registered yet (which requires an additional refundable stake key deposit).


    <figure><img src="/img/gitbook/drep%20reg%209.webp" alt=""><figcaption></figcaption></figure>



#### Store data using IPFS <a href="#ipfs" id="ipfs"></a>

One of the simplest ways to store data using IPFS is by using the IPFS desktop app. You can download it here: [https://docs.ipfs.tech/install/ipfs-desktop/](https://docs.ipfs.tech/install/ipfs-desktop/)

<figure><img src="/img/gitbook/Screenshot%202025-02-24%20at%2017.12.18.webp" alt=""><figcaption><p>IPFS Download page</p></figcaption></figure>

Choose your platform and download and install the desktop app on your computer.

Upload the .jsonld file you from GovTool to IPFS by using the "Import > File" option on the top right of the screen

<figure><img src="/img/gitbook/Screenshot%202025-02-24%20at%2017.19.41.webp" alt=""><figcaption></figcaption></figure>

Once the file is uploaded, you need to set it's 'pinning'. Select the file in the list, click on the three dots at the far right of the screen, and choose "Set Pinning"

<figure><img src="/img/gitbook/Screenshot%202025-02-24%20at%2017.24.55.webp" alt=""><figcaption></figcaption></figure>

Click the "Local Node" checkbox and then the "Apply" button

<figure><img src="/img/gitbook/Screenshot%202025-02-24%20at%2017.25.20.webp" alt=""><figcaption></figcaption></figure>

You will now see the Files list again. Click the three dots again, and choose "Share Link"

<figure><img src="/img/gitbook/Screenshot%202025-02-24%20at%2017.26.01.webp" alt=""><figcaption></figcaption></figure>

Click "Copy" to copy the link

<figure><img src="/img/gitbook/image.webp" alt=""><figcaption></figcaption></figure>

Paste it back into GovTool and click "Submit"

<figure><img src="/img/gitbook/image%20%281%29.webp" alt=""><figcaption></figcaption></figure>

Sign the transaction with your wallet:

<figure><img src="/img/gitbook/image%20%282%29.webp" alt=""><figcaption></figcaption></figure>

Your transaction will be checked and submitted:

<figure><img src="/img/gitbook/image%20%283%29.webp" alt=""><figcaption></figcaption></figure>

You can return to the dashboard, and when the transaction is submitted, you will see your DRep registration there.

<figure><img src="/img/gitbook/image%20%284%29.webp" alt=""><figcaption></figcaption></figure>

You are now registered and can vote as a DRep and also accept delegated voting power from others.
