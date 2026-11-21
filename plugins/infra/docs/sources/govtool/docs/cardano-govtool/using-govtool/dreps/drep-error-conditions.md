# DRep error conditions

## There are six possible errors with DRep data

These errors arise when GovTool cannot find or cannot verify the data entered and stored by the DRep, at the time of the most recent registration or data change&#x20;

### Data Missing

#### The data that was originally used when this DRep was created has not been found.&#x20;

GovTool uses external sources for DRep data, and these sources are maintained by the DReps themselves. This error means that GovTool cannot locate the data on the URL specified when the DRep was originally registered.



### Data Not Verifiable

#### The data that was originally used when this DRep was created has changed.&#x20;

GovTool uses external sources for DRep data, and these sources are maintained by the DReps themselves. This error means that the data stored by the DRep does not match the data supplied by the DRep when they originally registered

### Data Formatted Incorrectly

#### The data that was originally used when this DRep was created has been formatted incorrectly.&#x20;

GovTool uses external sources for DRep data, and these sources are maintained by the DReps themselves. This error means that the data stored by the DRep does not match the format defined by the DRep spec.

### Data URL Blocked

#### The URL this DRep registered points to an address GovTool does not fetch from.

GovTool uses external sources for DRep data, and these sources are maintained by the DReps themselves. GovTool only fetches data from public internet addresses, and this URL points to a private, local or otherwise blocked address.

### Data Too Large

#### The data that was originally used when this DRep was created is too large to load.

GovTool uses external sources for DRep data, and these sources are maintained by the DReps themselves. This error means that the file at the URL is larger than the 2 MB GovTool accepts.

### Data Not Checked

#### GovTool could not check the data for this DRep.

Something went wrong on GovTool's side while checking this DRep's data. This is not a problem with the DRep's data. Please try again later.

## Governance action data errors

Governance actions show the same six errors. GovTool uses external sources for Governance Action data, and these sources are maintained by the proposers of the Actions.

* **Data Missing**: GovTool cannot locate the data on the URL specified when the Governance Action was originally posted.
* **Data Not Verifiable**: the data stored by the Proposer does not match the data when the Governance Action was originally posted.
* **Data Formatted Incorrectly**: the data stored by the Proposer does not match the data format as defined by the Cardano community.
* **Data URL Blocked**: the URL this Governance Action was posted with points to an address GovTool does not fetch from. GovTool only fetches data from public internet addresses, and this URL points to a private, local or otherwise blocked address.
* **Data Too Large**: the file at the URL is larger than the 2 MB GovTool accepts.
* **Data Not Checked**: something went wrong on GovTool's side while checking this Governance Action's data. This is not a problem with the proposer's data. Please try again later.

## Errors during registration or update

When you register or update your DRep data, GovTool checks the URL you provide before submitting the transaction:

* **The URL You Entered Cannot Be Found**: GovTool could not download a file from the URL. Check that the URL is public and correct.
* **Your External Data Does Not Match the Original File.**: the file at the URL is not identical to the file you downloaded from GovTool. Upload the exact file again without modifying it.
