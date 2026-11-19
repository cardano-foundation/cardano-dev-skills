# Cardano Trace Documentation

## Table Of Contents

### [Trace Messages](#trace-messages)

1. __BlockFetch__
    1. __Clientⓣⓢ__
        1. [AcknowledgedFetchRequest](#blockfetchclientacknowledgedfetchrequest)
        1. [AddedFetchRequest](#blockfetchclientaddedfetchrequest)
        1. [ClientMetrics](#blockfetchclientclientmetrics)
        1. [ClientTerminating](#blockfetchclientclientterminating)
        1. [CompletedBlockFetch](#blockfetchclientcompletedblockfetch)
        1. [CompletedFetchBatch](#blockfetchclientcompletedfetchbatch)
        1. [RejectedFetchBatch](#blockfetchclientrejectedfetchbatch)
        1. [SendFetchRequest](#blockfetchclientsendfetchrequest)
        1. [StartedFetchBatch](#blockfetchclientstartedfetchbatch)
    1. __Decisionⓣⓜ__
        1. [Accept](#blockfetchdecisionaccept)
        1. [Decline](#blockfetchdecisiondecline)
        1. [EmptyPeersFetch](#blockfetchdecisionemptypeersfetch)
    1. __Remoteⓣⓢ__
        1. __Receive__
            1. [BatchDone](#blockfetchremotereceivebatchdone)
            1. [Block](#blockfetchremotereceiveblock)
            1. [ClientDone](#blockfetchremotereceiveclientdone)
            1. [NoBlocks](#blockfetchremotereceivenoblocks)
            1. [RequestRange](#blockfetchremotereceiverequestrange)
            1. [StartBatch](#blockfetchremotereceivestartbatch)
        1. __Send__
            1. [BatchDone](#blockfetchremotesendbatchdone)
            1. [Block](#blockfetchremotesendblock)
            1. [ClientDone](#blockfetchremotesendclientdone)
            1. [NoBlocks](#blockfetchremotesendnoblocks)
            1. [RequestRange](#blockfetchremotesendrequestrange)
            1. [StartBatch](#blockfetchremotesendstartbatch)
        1. __Serialisedⓣⓢ__
            1. __Receive__
                1. [BatchDone](#blockfetchremoteserialisedreceivebatchdone)
                1. [Block](#blockfetchremoteserialisedreceiveblock)
                1. [ClientDone](#blockfetchremoteserialisedreceiveclientdone)
                1. [NoBlocks](#blockfetchremoteserialisedreceivenoblocks)
                1. [RequestRange](#blockfetchremoteserialisedreceiverequestrange)
                1. [StartBatch](#blockfetchremoteserialisedreceivestartbatch)
            1. __Send__
                1. [BatchDone](#blockfetchremoteserialisedsendbatchdone)
                1. [Block](#blockfetchremoteserialisedsendblock)
                1. [ClientDone](#blockfetchremoteserialisedsendclientdone)
                1. [NoBlocks](#blockfetchremoteserialisedsendnoblocks)
                1. [RequestRange](#blockfetchremoteserialisedsendrequestrange)
                1. [StartBatch](#blockfetchremoteserialisedsendstartbatch)
    1. __Serverⓣⓜ__
        1. [SendBlock](#blockfetchserversendblock)
1. __BlockchainTimeⓣ__
    1. [CurrentSlotUnknown](#blockchaintimecurrentslotunknown)
    1. [StartTimeInTheFuture](#blockchaintimestarttimeinthefuture)
    1. [SystemClockMovedBack](#blockchaintimesystemclockmovedback)
1. __ChainDBⓣⓜ__
    1. __AddBlockEvent__
        1. __AddBlockValidation__
            1. [CandidateContainsFutureBlocks](#chaindbaddblockeventaddblockvalidationcandidatecontainsfutureblocks)
            1. [CandidateContainsFutureBlocksExceedingClockSkew](#chaindbaddblockeventaddblockvalidationcandidatecontainsfutureblocksexceedingclockskew)
            1. [InvalidBlock](#chaindbaddblockeventaddblockvalidationinvalidblock)
            1. [UpdateLedgerDb](#chaindbaddblockeventaddblockvalidationupdateledgerdb)
            1. [ValidCandidate](#chaindbaddblockeventaddblockvalidationvalidcandidate)
        1. [AddedBlockToQueue](#chaindbaddblockeventaddedblocktoqueue)
        1. [AddedBlockToVolatileDB](#chaindbaddblockeventaddedblocktovolatiledb)
        1. [AddedReprocessLoEBlocksToQueue](#chaindbaddblockeventaddedreprocessloeblockstoqueue)
        1. [AddedToCurrentChain](#chaindbaddblockeventaddedtocurrentchain)
        1. [BlockInTheFuture](#chaindbaddblockeventblockinthefuture)
        1. [ChainSelectionForFutureBlock](#chaindbaddblockeventchainselectionforfutureblock)
        1. [ChainSelectionLoEDebug](#chaindbaddblockeventchainselectionloedebug)
        1. [ChangingSelection](#chaindbaddblockeventchangingselection)
        1. [IgnoreBlockAlreadyInVolatileDB](#chaindbaddblockeventignoreblockalreadyinvolatiledb)
        1. [IgnoreBlockOlderThanK](#chaindbaddblockeventignoreblockolderthank)
        1. [IgnoreInvalidBlock](#chaindbaddblockeventignoreinvalidblock)
        1. __PipeliningEvent__
            1. [OutdatedTentativeHeader](#chaindbaddblockeventpipeliningeventoutdatedtentativeheader)
            1. [SetTentativeHeader](#chaindbaddblockeventpipeliningeventsettentativeheader)
            1. [TrapTentativeHeader](#chaindbaddblockeventpipeliningeventtraptentativeheader)
        1. [PoppedBlockFromQueue](#chaindbaddblockeventpoppedblockfromqueue)
        1. [PoppedReprocessLoEBlocksFromQueue](#chaindbaddblockeventpoppedreprocessloeblocksfromqueue)
        1. [StoreButDontChange](#chaindbaddblockeventstorebutdontchange)
        1. [SwitchedToAFork](#chaindbaddblockeventswitchedtoafork)
        1. [TryAddToCurrentChain](#chaindbaddblockeventtryaddtocurrentchain)
        1. [TrySwitchToAFork](#chaindbaddblockeventtryswitchtoafork)
    1. __CopyToImmutableDBEvent__
        1. [CopiedBlockToImmutableDB](#chaindbcopytoimmutabledbeventcopiedblocktoimmutabledb)
        1. [NoBlocksToCopyToImmutableDB](#chaindbcopytoimmutabledbeventnoblockstocopytoimmutabledb)
    1. __FollowerEvent__
        1. [FollowerNewImmIterator](#chaindbfollowereventfollowernewimmiterator)
        1. [FollowerNoLongerInMem](#chaindbfollowereventfollowernolongerinmem)
        1. [FollowerSwitchToMem](#chaindbfollowereventfollowerswitchtomem)
        1. [NewFollower](#chaindbfollowereventnewfollower)
    1. __GCEvent__
        1. [PerformedGC](#chaindbgceventperformedgc)
        1. [ScheduledGC](#chaindbgceventscheduledgc)
    1. __ImmDbEvent__
        1. __CacheEvent__
            1. [CurrentChunkHit](#chaindbimmdbeventcacheeventcurrentchunkhit)
            1. [PastChunkEvict](#chaindbimmdbeventcacheeventpastchunkevict)
            1. [PastChunkExpired](#chaindbimmdbeventcacheeventpastchunkexpired)
            1. [PastChunkHit](#chaindbimmdbeventcacheeventpastchunkhit)
            1. [PastChunkMiss](#chaindbimmdbeventcacheeventpastchunkmiss)
        1. [ChunkFileDoesntFit](#chaindbimmdbeventchunkfiledoesntfit)
        1. __ChunkValidation__
            1. [InvalidChunkFile](#chaindbimmdbeventchunkvalidationinvalidchunkfile)
            1. [InvalidPrimaryIndex](#chaindbimmdbeventchunkvalidationinvalidprimaryindex)
            1. [InvalidSecondaryIndex](#chaindbimmdbeventchunkvalidationinvalidsecondaryindex)
            1. [MissingChunkFile](#chaindbimmdbeventchunkvalidationmissingchunkfile)
            1. [MissingPrimaryIndex](#chaindbimmdbeventchunkvalidationmissingprimaryindex)
            1. [MissingSecondaryIndex](#chaindbimmdbeventchunkvalidationmissingsecondaryindex)
            1. [RewritePrimaryIndex](#chaindbimmdbeventchunkvalidationrewriteprimaryindex)
            1. [RewriteSecondaryIndex](#chaindbimmdbeventchunkvalidationrewritesecondaryindex)
            1. [StartedValidatingChunk](#chaindbimmdbeventchunkvalidationstartedvalidatingchunk)
            1. [ValidatedChunk](#chaindbimmdbeventchunkvalidationvalidatedchunk)
        1. [DBAlreadyClosed](#chaindbimmdbeventdbalreadyclosed)
        1. [DBClosed](#chaindbimmdbeventdbclosed)
        1. [DeletingAfter](#chaindbimmdbeventdeletingafter)
        1. [Migrating](#chaindbimmdbeventmigrating)
        1. [NoValidLastLocation](#chaindbimmdbeventnovalidlastlocation)
        1. [ValidatedLastLocation](#chaindbimmdbeventvalidatedlastlocation)
    1. __InitChainSelEvent__
        1. [InitialChainSelected](#chaindbinitchainseleventinitialchainselected)
        1. [StartedInitChainSelection](#chaindbinitchainseleventstartedinitchainselection)
        1. __Validation__
            1. [CandidateContainsFutureBlocks](#chaindbinitchainseleventvalidationcandidatecontainsfutureblocks)
            1. [CandidateContainsFutureBlocksExceedingClockSkew](#chaindbinitchainseleventvalidationcandidatecontainsfutureblocksexceedingclockskew)
            1. [InvalidBlock](#chaindbinitchainseleventvalidationinvalidblock)
            1. [UpdateLedgerDb](#chaindbinitchainseleventvalidationupdateledgerdb)
            1. [ValidCandidate](#chaindbinitchainseleventvalidationvalidcandidate)
    1. __IteratorEvent__
        1. [BlockGCedFromVolatileDB](#chaindbiteratoreventblockgcedfromvolatiledb)
        1. [BlockMissingFromVolatileDB](#chaindbiteratoreventblockmissingfromvolatiledb)
        1. [BlockWasCopiedToImmutableDB](#chaindbiteratoreventblockwascopiedtoimmutabledb)
        1. [StreamFromBoth](#chaindbiteratoreventstreamfromboth)
        1. [StreamFromImmutableDB](#chaindbiteratoreventstreamfromimmutabledb)
        1. [StreamFromVolatileDB](#chaindbiteratoreventstreamfromvolatiledb)
        1. [SwitchBackToVolatileDB](#chaindbiteratoreventswitchbacktovolatiledb)
        1. __UnknownRangeRequested__
            1. [ForkTooOld](#chaindbiteratoreventunknownrangerequestedforktooold)
            1. [MissingBlock](#chaindbiteratoreventunknownrangerequestedmissingblock)
    1. __LedgerEvent__
        1. [DeletedSnapshot](#chaindbledgereventdeletedsnapshot)
        1. [InvalidSnapshot](#chaindbledgereventinvalidsnapshot)
        1. [TookSnapshot](#chaindbledgereventtooksnapshot)
    1. __LedgerReplay__
        1. [ReplayFromGenesis](#chaindbledgerreplayreplayfromgenesis)
        1. [ReplayFromSnapshot](#chaindbledgerreplayreplayfromsnapshot)
        1. [ReplayedBlock](#chaindbledgerreplayreplayedblock)
    1. __OpenEvent__
        1. [ClosedDB](#chaindbopeneventcloseddb)
        1. [OpenedDB](#chaindbopeneventopeneddb)
        1. [OpenedImmutableDB](#chaindbopeneventopenedimmutabledb)
        1. [OpenedLgrDB](#chaindbopeneventopenedlgrdb)
        1. [OpenedVolatileDB](#chaindbopeneventopenedvolatiledb)
        1. [StartedOpeningDB](#chaindbopeneventstartedopeningdb)
        1. [StartedOpeningImmutableDB](#chaindbopeneventstartedopeningimmutabledb)
        1. [StartedOpeningLgrDB](#chaindbopeneventstartedopeninglgrdb)
        1. [StartedOpeningVolatileDB](#chaindbopeneventstartedopeningvolatiledb)
    1. __ReplayBlockⓣⓜ__
        1. [LedgerReplay](#chaindbreplayblockledgerreplay)
    1. __VolatileDbEvent__
        1. [BlockAlreadyHere](#chaindbvolatiledbeventblockalreadyhere)
        1. [DBAlreadyClosed](#chaindbvolatiledbeventdbalreadyclosed)
        1. [DBClosed](#chaindbvolatiledbeventdbclosed)
        1. [InvalidFileNames](#chaindbvolatiledbeventinvalidfilenames)
        1. [Truncate](#chaindbvolatiledbeventtruncate)
1. __ChainSync__
    1. __Clientⓣ__
        1. [AccessingForecastHorizon](#chainsyncclientaccessingforecasthorizon)
        1. [DownloadedHeader](#chainsyncclientdownloadedheader)
        1. [Exception](#chainsyncclientexception)
        1. [FoundIntersection](#chainsyncclientfoundintersection)
        1. [GaveLoPToken](#chainsyncclientgaveloptoken)
        1. [JumpResult](#chainsyncclientjumpresult)
        1. [JumpingInstructionIs](#chainsyncclientjumpinginstructionis)
        1. [JumpingWaitingForNextInstruction](#chainsyncclientjumpingwaitingfornextinstruction)
        1. [OfferJump](#chainsyncclientofferjump)
        1. [RolledBack](#chainsyncclientrolledback)
        1. [Termination](#chainsyncclienttermination)
        1. [ValidatedHeader](#chainsyncclientvalidatedheader)
        1. [WaitingBeyondForecastHorizon](#chainsyncclientwaitingbeyondforecasthorizon)
    1. __Localⓣⓢ__
        1. __Receive__
            1. [AwaitReply](#chainsynclocalreceiveawaitreply)
            1. [Done](#chainsynclocalreceivedone)
            1. [FindIntersect](#chainsynclocalreceivefindintersect)
            1. [IntersectFound](#chainsynclocalreceiveintersectfound)
            1. [IntersectNotFound](#chainsynclocalreceiveintersectnotfound)
            1. [RequestNext](#chainsynclocalreceiverequestnext)
            1. [RollBackward](#chainsynclocalreceiverollbackward)
            1. [RollForward](#chainsynclocalreceiverollforward)
        1. __Send__
            1. [AwaitReply](#chainsynclocalsendawaitreply)
            1. [Done](#chainsynclocalsenddone)
            1. [FindIntersect](#chainsynclocalsendfindintersect)
            1. [IntersectFound](#chainsynclocalsendintersectfound)
            1. [IntersectNotFound](#chainsynclocalsendintersectnotfound)
            1. [RequestNext](#chainsynclocalsendrequestnext)
            1. [RollBackward](#chainsynclocalsendrollbackward)
            1. [RollForward](#chainsynclocalsendrollforward)
    1. __Remoteⓣⓢ__
        1. __Receive__
            1. [AwaitReply](#chainsyncremotereceiveawaitreply)
            1. [Done](#chainsyncremotereceivedone)
            1. [FindIntersect](#chainsyncremotereceivefindintersect)
            1. [IntersectFound](#chainsyncremotereceiveintersectfound)
            1. [IntersectNotFound](#chainsyncremotereceiveintersectnotfound)
            1. [RequestNext](#chainsyncremotereceiverequestnext)
            1. [RollBackward](#chainsyncremotereceiverollbackward)
            1. [RollForward](#chainsyncremotereceiverollforward)
        1. __Send__
            1. [AwaitReply](#chainsyncremotesendawaitreply)
            1. [Done](#chainsyncremotesenddone)
            1. [FindIntersect](#chainsyncremotesendfindintersect)
            1. [IntersectFound](#chainsyncremotesendintersectfound)
            1. [IntersectNotFound](#chainsyncremotesendintersectnotfound)
            1. [RequestNext](#chainsyncremotesendrequestnext)
            1. [RollBackward](#chainsyncremotesendrollbackward)
            1. [RollForward](#chainsyncremotesendrollforward)
        1. __Serialisedⓣⓢ__
            1. __Receive__
                1. [AwaitReply](#chainsyncremoteserialisedreceiveawaitreply)
                1. [Done](#chainsyncremoteserialisedreceivedone)
                1. [FindIntersect](#chainsyncremoteserialisedreceivefindintersect)
                1. [IntersectFound](#chainsyncremoteserialisedreceiveintersectfound)
                1. [IntersectNotFound](#chainsyncremoteserialisedreceiveintersectnotfound)
                1. [RequestNext](#chainsyncremoteserialisedreceiverequestnext)
                1. [RollBackward](#chainsyncremoteserialisedreceiverollbackward)
                1. [RollForward](#chainsyncremoteserialisedreceiverollforward)
            1. __Send__
                1. [AwaitReply](#chainsyncremoteserialisedsendawaitreply)
                1. [Done](#chainsyncremoteserialisedsenddone)
                1. [FindIntersect](#chainsyncremoteserialisedsendfindintersect)
                1. [IntersectFound](#chainsyncremoteserialisedsendintersectfound)
                1. [IntersectNotFound](#chainsyncremoteserialisedsendintersectnotfound)
                1. [RequestNext](#chainsyncremoteserialisedsendrequestnext)
                1. [RollBackward](#chainsyncremoteserialisedsendrollbackward)
                1. [RollForward](#chainsyncremoteserialisedsendrollforward)
    1. __ServerBlockⓣⓢ__
        1. [Update](#chainsyncserverblockupdate)
    1. __ServerHeaderⓣⓢ__
        1. [Update](#chainsyncserverheaderupdate)
1. __Forgeⓣⓜ__
    1. __Loopⓣⓜ__
        1. [AdoptedBlock](#forgeloopadoptedblock)
        1. [AdoptionThreadDied](#forgeloopadoptionthreaddied)
        1. [BlockContext](#forgeloopblockcontext)
        1. [BlockFromFuture](#forgeloopblockfromfuture)
        1. [DidntAdoptBlock](#forgeloopdidntadoptblock)
        1. [ForgeStateUpdateError](#forgeloopforgestateupdateerror)
        1. [ForgeTickedLedgerState](#forgeloopforgetickedledgerstate)
        1. [ForgedBlock](#forgeloopforgedblock)
        1. [ForgedInvalidBlock](#forgeloopforgedinvalidblock)
        1. [ForgingMempoolSnapshot](#forgeloopforgingmempoolsnapshot)
        1. [LedgerState](#forgeloopledgerstate)
        1. [LedgerView](#forgeloopledgerview)
        1. [NoLedgerState](#forgeloopnoledgerstate)
        1. [NoLedgerView](#forgeloopnoledgerview)
        1. [NodeCannotForge](#forgeloopnodecannotforge)
        1. [NodeIsLeader](#forgeloopnodeisleader)
        1. [NodeNotLeader](#forgeloopnodenotleader)
        1. [SlotIsImmutable](#forgeloopslotisimmutable)
        1. [StartLeadershipCheck](#forgeloopstartleadershipcheck)
        1. [StartLeadershipCheckPlus](#forgeloopstartleadershipcheckplus)
    1. [StateInfo](#forgestateinfo)
    1. __ThreadStatsⓣⓢ__
        1. [ForgeThreadStats](#forgethreadstatsforgethreadstats)
1. __Mempoolⓣⓜ__
    1. [AddedTx](#mempooladdedtx)
    1. [ManuallyRemovedTxs](#mempoolmanuallyremovedtxs)
    1. [RejectedTx](#mempoolrejectedtx)
    1. [RemoveTxs](#mempoolremovetxs)
1. __Netⓣⓢ__
    1. __AcceptPolicyⓣ__
        1. [ConnectionHardLimit](#netacceptpolicyconnectionhardlimit)
        1. [ConnectionLimitResume](#netacceptpolicyconnectionlimitresume)
        1. [ConnectionRateLimiting](#netacceptpolicyconnectionratelimiting)
    1. __Churnⓣⓢ__
        1. [ChurnCounters](#netchurnchurncounters)
    1. __ConnectionManager__
        1. __Localⓣⓜ__
            1. [Connect](#netconnectionmanagerlocalconnect)
            1. [ConnectError](#netconnectionmanagerlocalconnecterror)
            1. [ConnectionCleanup](#netconnectionmanagerlocalconnectioncleanup)
            1. [ConnectionExists](#netconnectionmanagerlocalconnectionexists)
            1. [ConnectionFailure](#netconnectionmanagerlocalconnectionfailure)
            1. [ConnectionHandler](#netconnectionmanagerlocalconnectionhandler)
            1. [ConnectionManagerCounters](#netconnectionmanagerlocalconnectionmanagercounters)
            1. [ConnectionNotFound](#netconnectionmanagerlocalconnectionnotfound)
            1. [ConnectionTimeWait](#netconnectionmanagerlocalconnectiontimewait)
            1. [ConnectionTimeWaitDone](#netconnectionmanagerlocalconnectiontimewaitdone)
            1. [ForbiddenConnection](#netconnectionmanagerlocalforbiddenconnection)
            1. [ForbiddenOperation](#netconnectionmanagerlocalforbiddenoperation)
            1. [ImpossibleConnection](#netconnectionmanagerlocalimpossibleconnection)
            1. [IncludeConnection](#netconnectionmanagerlocalincludeconnection)
            1. [PruneConnections](#netconnectionmanagerlocalpruneconnections)
            1. [Shutdown](#netconnectionmanagerlocalshutdown)
            1. [State](#netconnectionmanagerlocalstate)
            1. [TerminatedConnection](#netconnectionmanagerlocalterminatedconnection)
            1. [TerminatingConnection](#netconnectionmanagerlocalterminatingconnection)
            1. [UnexpectedlyFalseAssertion](#netconnectionmanagerlocalunexpectedlyfalseassertion)
            1. [UnregisterConnection](#netconnectionmanagerlocalunregisterconnection)
        1. __Remoteⓣⓜ__
            1. [Connect](#netconnectionmanagerremoteconnect)
            1. [ConnectError](#netconnectionmanagerremoteconnecterror)
            1. [ConnectionCleanup](#netconnectionmanagerremoteconnectioncleanup)
            1. [ConnectionExists](#netconnectionmanagerremoteconnectionexists)
            1. [ConnectionFailure](#netconnectionmanagerremoteconnectionfailure)
            1. [ConnectionHandler](#netconnectionmanagerremoteconnectionhandler)
            1. [ConnectionManagerCounters](#netconnectionmanagerremoteconnectionmanagercounters)
            1. [ConnectionNotFound](#netconnectionmanagerremoteconnectionnotfound)
            1. [ConnectionTimeWait](#netconnectionmanagerremoteconnectiontimewait)
            1. [ConnectionTimeWaitDone](#netconnectionmanagerremoteconnectiontimewaitdone)
            1. [ForbiddenConnection](#netconnectionmanagerremoteforbiddenconnection)
            1. [ForbiddenOperation](#netconnectionmanagerremoteforbiddenoperation)
            1. [ImpossibleConnection](#netconnectionmanagerremoteimpossibleconnection)
            1. [IncludeConnection](#netconnectionmanagerremoteincludeconnection)
            1. [PruneConnections](#netconnectionmanagerremotepruneconnections)
            1. [Shutdown](#netconnectionmanagerremoteshutdown)
            1. [State](#netconnectionmanagerremotestate)
            1. [TerminatedConnection](#netconnectionmanagerremoteterminatedconnection)
            1. [TerminatingConnection](#netconnectionmanagerremoteterminatingconnection)
            1. [UnexpectedlyFalseAssertion](#netconnectionmanagerremoteunexpectedlyfalseassertion)
            1. [UnregisterConnection](#netconnectionmanagerremoteunregisterconnection)
        1. __Transitionⓣⓢ__
            1. [Transition](#netconnectionmanagertransitiontransition)
    1. __DNSResolverⓣ__
        1. [LookupAAAAError](#netdnsresolverlookupaaaaerror)
        1. [LookupAAAAResult](#netdnsresolverlookupaaaaresult)
        1. [LookupAError](#netdnsresolverlookupaerror)
        1. [LookupAResult](#netdnsresolverlookuparesult)
        1. [LookupException](#netdnsresolverlookupexception)
        1. [LookupIPv4First](#netdnsresolverlookupipv4first)
        1. [LookupIPv6First](#netdnsresolverlookupipv6first)
    1. __ErrorPolicy__
        1. __Localⓣ__
            1. [AcceptException](#neterrorpolicylocalacceptexception)
            1. [KeepSuspended](#neterrorpolicylocalkeepsuspended)
            1. [LocalNodeError](#neterrorpolicylocallocalnodeerror)
            1. [ResumeConsumer](#neterrorpolicylocalresumeconsumer)
            1. [ResumePeer](#neterrorpolicylocalresumepeer)
            1. [ResumeProducer](#neterrorpolicylocalresumeproducer)
            1. [SuspendConsumer](#neterrorpolicylocalsuspendconsumer)
            1. [SuspendPeer](#neterrorpolicylocalsuspendpeer)
            1. [UnhandledApplicationException](#neterrorpolicylocalunhandledapplicationexception)
            1. [UnhandledConnectionException](#neterrorpolicylocalunhandledconnectionexception)
        1. __Remoteⓣ__
            1. [AcceptException](#neterrorpolicyremoteacceptexception)
            1. [KeepSuspended](#neterrorpolicyremotekeepsuspended)
            1. [LocalNodeError](#neterrorpolicyremotelocalnodeerror)
            1. [ResumeConsumer](#neterrorpolicyremoteresumeconsumer)
            1. [ResumePeer](#neterrorpolicyremoteresumepeer)
            1. [ResumeProducer](#neterrorpolicyremoteresumeproducer)
            1. [SuspendConsumer](#neterrorpolicyremotesuspendconsumer)
            1. [SuspendPeer](#neterrorpolicyremotesuspendpeer)
            1. [UnhandledApplicationException](#neterrorpolicyremoteunhandledapplicationexception)
            1. [UnhandledConnectionException](#neterrorpolicyremoteunhandledconnectionexception)
    1. __Handshake__
        1. __Localⓣⓢ__
            1. __Receive__
                1. [AcceptVersion](#nethandshakelocalreceiveacceptversion)
                1. [MsgQueryReply](#nethandshakelocalreceivemsgqueryreply)
                1. [ProposeVersions](#nethandshakelocalreceiveproposeversions)
                1. [Refuse](#nethandshakelocalreceiverefuse)
                1. [ReplyVersions](#nethandshakelocalreceivereplyversions)
            1. __Send__
                1. [AcceptVersion](#nethandshakelocalsendacceptversion)
                1. [MsgQueryReply](#nethandshakelocalsendmsgqueryreply)
                1. [ProposeVersions](#nethandshakelocalsendproposeversions)
                1. [Refuse](#nethandshakelocalsendrefuse)
                1. [ReplyVersions](#nethandshakelocalsendreplyversions)
        1. __Remoteⓣⓢ__
            1. __Receive__
                1. [AcceptVersion](#nethandshakeremotereceiveacceptversion)
                1. [MsgQueryReply](#nethandshakeremotereceivemsgqueryreply)
                1. [ProposeVersions](#nethandshakeremotereceiveproposeversions)
                1. [Refuse](#nethandshakeremotereceiverefuse)
                1. [ReplyVersions](#nethandshakeremotereceivereplyversions)
            1. __Send__
                1. [AcceptVersion](#nethandshakeremotesendacceptversion)
                1. [MsgQueryReply](#nethandshakeremotesendmsgqueryreply)
                1. [ProposeVersions](#nethandshakeremotesendproposeversions)
                1. [Refuse](#nethandshakeremotesendrefuse)
                1. [ReplyVersions](#nethandshakeremotesendreplyversions)
    1. __InboundGovernor__
        1. __Localⓣⓜ__
            1. [DemotedToColdRemote](#netinboundgovernorlocaldemotedtocoldremote)
            1. [DemotedToWarmRemote](#netinboundgovernorlocaldemotedtowarmremote)
            1. [Inactive](#netinboundgovernorlocalinactive)
            1. [InboundGovernorCounters](#netinboundgovernorlocalinboundgovernorcounters)
            1. [InboundGovernorError](#netinboundgovernorlocalinboundgovernorerror)
            1. [MaturedConnections](#netinboundgovernorlocalmaturedconnections)
            1. [MuxCleanExit](#netinboundgovernorlocalmuxcleanexit)
            1. [MuxErrored](#netinboundgovernorlocalmuxerrored)
            1. [NewConnection](#netinboundgovernorlocalnewconnection)
            1. [PromotedToHotRemote](#netinboundgovernorlocalpromotedtohotremote)
            1. [PromotedToWarmRemote](#netinboundgovernorlocalpromotedtowarmremote)
            1. [RemoteState](#netinboundgovernorlocalremotestate)
            1. [ResponderErrored](#netinboundgovernorlocalrespondererrored)
            1. [ResponderRestarted](#netinboundgovernorlocalresponderrestarted)
            1. [ResponderStartFailure](#netinboundgovernorlocalresponderstartfailure)
            1. [ResponderStarted](#netinboundgovernorlocalresponderstarted)
            1. [ResponderTerminated](#netinboundgovernorlocalresponderterminated)
            1. [UnexpectedlyFalseAssertion](#netinboundgovernorlocalunexpectedlyfalseassertion)
            1. [WaitIdleRemote](#netinboundgovernorlocalwaitidleremote)
        1. __Remoteⓣⓜ__
            1. [DemotedToColdRemote](#netinboundgovernorremotedemotedtocoldremote)
            1. [DemotedToWarmRemote](#netinboundgovernorremotedemotedtowarmremote)
            1. [Inactive](#netinboundgovernorremoteinactive)
            1. [InboundGovernorCounters](#netinboundgovernorremoteinboundgovernorcounters)
            1. [InboundGovernorError](#netinboundgovernorremoteinboundgovernorerror)
            1. [MaturedConnections](#netinboundgovernorremotematuredconnections)
            1. [MuxCleanExit](#netinboundgovernorremotemuxcleanexit)
            1. [MuxErrored](#netinboundgovernorremotemuxerrored)
            1. [NewConnection](#netinboundgovernorremotenewconnection)
            1. [PromotedToHotRemote](#netinboundgovernorremotepromotedtohotremote)
            1. [PromotedToWarmRemote](#netinboundgovernorremotepromotedtowarmremote)
            1. [RemoteState](#netinboundgovernorremoteremotestate)
            1. [ResponderErrored](#netinboundgovernorremoterespondererrored)
            1. [ResponderRestarted](#netinboundgovernorremoteresponderrestarted)
            1. [ResponderStartFailure](#netinboundgovernorremoteresponderstartfailure)
            1. [ResponderStarted](#netinboundgovernorremoteresponderstarted)
            1. [ResponderTerminated](#netinboundgovernorremoteresponderterminated)
            1. [UnexpectedlyFalseAssertion](#netinboundgovernorremoteunexpectedlyfalseassertion)
            1. [WaitIdleRemote](#netinboundgovernorremotewaitidleremote)
        1. __Transitionⓣ__
            1. [Transition](#netinboundgovernortransitiontransition)
    1. [KeepAliveClient](#netkeepaliveclient)
    1. __Mux__
        1. __Localⓣ__
            1. [ChannelRecvEnd](#netmuxlocalchannelrecvend)
            1. [ChannelRecvStart](#netmuxlocalchannelrecvstart)
            1. [ChannelSendEnd](#netmuxlocalchannelsendend)
            1. [ChannelSendStart](#netmuxlocalchannelsendstart)
            1. [CleanExit](#netmuxlocalcleanexit)
            1. [ExceptionExit](#netmuxlocalexceptionexit)
            1. [HandshakeClientEnd](#netmuxlocalhandshakeclientend)
            1. [HandshakeClientError](#netmuxlocalhandshakeclienterror)
            1. [HandshakeServerEnd](#netmuxlocalhandshakeserverend)
            1. [HandshakeServerError](#netmuxlocalhandshakeservererror)
            1. [HandshakeStart](#netmuxlocalhandshakestart)
            1. [RecvDeltaQObservation](#netmuxlocalrecvdeltaqobservation)
            1. [RecvDeltaQSample](#netmuxlocalrecvdeltaqsample)
            1. [RecvEnd](#netmuxlocalrecvend)
            1. [RecvHeaderEnd](#netmuxlocalrecvheaderend)
            1. [RecvHeaderStart](#netmuxlocalrecvheaderstart)
            1. [RecvStart](#netmuxlocalrecvstart)
            1. [SDUReadTimeoutException](#netmuxlocalsdureadtimeoutexception)
            1. [SDUWriteTimeoutException](#netmuxlocalsduwritetimeoutexception)
            1. [SendEnd](#netmuxlocalsendend)
            1. [SendStart](#netmuxlocalsendstart)
            1. [Shutdown](#netmuxlocalshutdown)
            1. [StartEagerly](#netmuxlocalstarteagerly)
            1. [StartOnDemand](#netmuxlocalstartondemand)
            1. [StartedOnDemand](#netmuxlocalstartedondemand)
            1. [State](#netmuxlocalstate)
            1. [Stopped](#netmuxlocalstopped)
            1. [Stopping](#netmuxlocalstopping)
            1. [TCPInfo](#netmuxlocaltcpinfo)
            1. [Terminating](#netmuxlocalterminating)
        1. __Remoteⓣ__
            1. [ChannelRecvEnd](#netmuxremotechannelrecvend)
            1. [ChannelRecvStart](#netmuxremotechannelrecvstart)
            1. [ChannelSendEnd](#netmuxremotechannelsendend)
            1. [ChannelSendStart](#netmuxremotechannelsendstart)
            1. [CleanExit](#netmuxremotecleanexit)
            1. [ExceptionExit](#netmuxremoteexceptionexit)
            1. [HandshakeClientEnd](#netmuxremotehandshakeclientend)
            1. [HandshakeClientError](#netmuxremotehandshakeclienterror)
            1. [HandshakeServerEnd](#netmuxremotehandshakeserverend)
            1. [HandshakeServerError](#netmuxremotehandshakeservererror)
            1. [HandshakeStart](#netmuxremotehandshakestart)
            1. [RecvDeltaQObservation](#netmuxremoterecvdeltaqobservation)
            1. [RecvDeltaQSample](#netmuxremoterecvdeltaqsample)
            1. [RecvEnd](#netmuxremoterecvend)
            1. [RecvHeaderEnd](#netmuxremoterecvheaderend)
            1. [RecvHeaderStart](#netmuxremoterecvheaderstart)
            1. [RecvStart](#netmuxremoterecvstart)
            1. [SDUReadTimeoutException](#netmuxremotesdureadtimeoutexception)
            1. [SDUWriteTimeoutException](#netmuxremotesduwritetimeoutexception)
            1. [SendEnd](#netmuxremotesendend)
            1. [SendStart](#netmuxremotesendstart)
            1. [Shutdown](#netmuxremoteshutdown)
            1. [StartEagerly](#netmuxremotestarteagerly)
            1. [StartOnDemand](#netmuxremotestartondemand)
            1. [StartedOnDemand](#netmuxremotestartedondemand)
            1. [State](#netmuxremotestate)
            1. [Stopped](#netmuxremotestopped)
            1. [Stopping](#netmuxremotestopping)
            1. [TCPInfo](#netmuxremotetcpinfo)
            1. [Terminating](#netmuxremoteterminating)
    1. __PeerSelection__
        1. __Actionsⓣ__
            1. [MonitoringError](#netpeerselectionactionsmonitoringerror)
            1. [MonitoringResult](#netpeerselectionactionsmonitoringresult)
            1. [StatusChangeFailure](#netpeerselectionactionsstatuschangefailure)
            1. [StatusChanged](#netpeerselectionactionsstatuschanged)
        1. __Countersⓣⓜ__
            1. [Counters](#netpeerselectioncounterscounters)
        1. __Initiatorⓣⓢ__
            1. [GovernorState](#netpeerselectioninitiatorgovernorstate)
        1. __Responderⓣⓢ__
            1. [GovernorState](#netpeerselectionrespondergovernorstate)
        1. __Selectionⓣ__
            1. [ChurnMode](#netpeerselectionselectionchurnmode)
            1. [ChurnWait](#netpeerselectionselectionchurnwait)
            1. [DebugState](#netpeerselectionselectiondebugstate)
            1. [DemoteAsynchronous](#netpeerselectionselectiondemoteasynchronous)
            1. [DemoteHotDone](#netpeerselectionselectiondemotehotdone)
            1. [DemoteHotFailed](#netpeerselectionselectiondemotehotfailed)
            1. [DemoteHotPeers](#netpeerselectionselectiondemotehotpeers)
            1. [DemoteLocalAsynchronous](#netpeerselectionselectiondemotelocalasynchronous)
            1. [DemoteLocalHotPeers](#netpeerselectionselectiondemotelocalhotpeers)
            1. [DemoteWarmDone](#netpeerselectionselectiondemotewarmdone)
            1. [DemoteWarmFailed](#netpeerselectionselectiondemotewarmfailed)
            1. [DemoteWarmPeers](#netpeerselectionselectiondemotewarmpeers)
            1. [ForgetColdPeers](#netpeerselectionselectionforgetcoldpeers)
            1. [GossipRequests](#netpeerselectionselectiongossiprequests)
            1. [GossipResults](#netpeerselectionselectiongossipresults)
            1. [GovernorWakeup](#netpeerselectionselectiongovernorwakeup)
            1. [LocalRootPeersChanged](#netpeerselectionselectionlocalrootpeerschanged)
            1. [OutboundGovernorCriticalFailure](#netpeerselectionselectionoutboundgovernorcriticalfailure)
            1. [PickInboundPeers](#netpeerselectionselectionpickinboundpeers)
            1. [PromoteColdDone](#netpeerselectionselectionpromotecolddone)
            1. [PromoteColdFailed](#netpeerselectionselectionpromotecoldfailed)
            1. [PromoteColdLocalPeers](#netpeerselectionselectionpromotecoldlocalpeers)
            1. [PromoteColdPeers](#netpeerselectionselectionpromotecoldpeers)
            1. [PromoteWarmAborted](#netpeerselectionselectionpromotewarmaborted)
            1. [PromoteWarmDone](#netpeerselectionselectionpromotewarmdone)
            1. [PromoteWarmFailed](#netpeerselectionselectionpromotewarmfailed)
            1. [PromoteWarmLocalPeers](#netpeerselectionselectionpromotewarmlocalpeers)
            1. [PromoteWarmPeers](#netpeerselectionselectionpromotewarmpeers)
            1. [PublicRootsFailure](#netpeerselectionselectionpublicrootsfailure)
            1. [PublicRootsRequest](#netpeerselectionselectionpublicrootsrequest)
            1. [PublicRootsResults](#netpeerselectionselectionpublicrootsresults)
            1. [TargetsChanged](#netpeerselectionselectiontargetschanged)
    1. __Peers__
        1. __Ledgerⓣⓢ__
            1. [DisabledLedgerPeers](#netpeersledgerdisabledledgerpeers)
            1. [FallingBackToPublicRootPeers](#netpeersledgerfallingbacktopublicrootpeers)
            1. [FetchingNewLedgerState](#netpeersledgerfetchingnewledgerstate)
            1. [PickedPeer](#netpeersledgerpickedpeer)
            1. [PickedPeers](#netpeersledgerpickedpeers)
            1. [RequestForPeers](#netpeersledgerrequestforpeers)
            1. [ReusingLedgerState](#netpeersledgerreusingledgerstate)
            1. [TraceLedgerPeersDomains](#netpeersledgertraceledgerpeersdomains)
            1. [TraceLedgerPeersFailure](#netpeersledgertraceledgerpeersfailure)
            1. [TraceLedgerPeersResult](#netpeersledgertraceledgerpeersresult)
            1. [TraceUseLedgerAfter](#netpeersledgertraceuseledgerafter)
            1. [WaitingOnRequest](#netpeersledgerwaitingonrequest)
        1. __Listⓣⓢ__
            1. [PeersFromNodeKernel](#netpeerslistpeersfromnodekernel)
        1. __LocalRootⓣ__
            1. [LocalRootDNSMap](#netpeerslocalrootlocalrootdnsmap)
            1. [LocalRootDomains](#netpeerslocalrootlocalrootdomains)
            1. [LocalRootError](#netpeerslocalrootlocalrooterror)
            1. [LocalRootFailure](#netpeerslocalrootlocalrootfailure)
            1. [LocalRootGroups](#netpeerslocalrootlocalrootgroups)
            1. [LocalRootReconfigured](#netpeerslocalrootlocalrootreconfigured)
            1. [LocalRootResult](#netpeerslocalrootlocalrootresult)
            1. [LocalRootWaiting](#netpeerslocalrootlocalrootwaiting)
        1. __PublicRootⓣ__
            1. [PublicRootDomains](#netpeerspublicrootpublicrootdomains)
            1. [PublicRootFailure](#netpeerspublicrootpublicrootfailure)
            1. [PublicRootRelayAccessPoint](#netpeerspublicrootpublicrootrelayaccesspoint)
            1. [PublicRootResult](#netpeerspublicrootpublicrootresult)
    1. __Server__
        1. __Localⓣ__
            1. [AcceptConnection](#netserverlocalacceptconnection)
            1. [AcceptError](#netserverlocalaccepterror)
            1. [AcceptPolicy](#netserverlocalacceptpolicy)
            1. [Error](#netserverlocalerror)
            1. [Started](#netserverlocalstarted)
            1. [Stopped](#netserverlocalstopped)
        1. __Remoteⓣ__
            1. [AcceptConnection](#netserverremoteacceptconnection)
            1. [AcceptError](#netserverremoteaccepterror)
            1. [AcceptPolicy](#netserverremoteacceptpolicy)
            1. [Error](#netserverremoteerror)
            1. [Started](#netserverremotestarted)
            1. [Stopped](#netserverremotestopped)
    1. __Subscription__
        1. __DNSⓣ__
            1. [AllocateSocket](#netsubscriptiondnsallocatesocket)
            1. [ApplicationException](#netsubscriptiondnsapplicationexception)
            1. [CloseSocket](#netsubscriptiondnsclosesocket)
            1. [ConnectEnd](#netsubscriptiondnsconnectend)
            1. [ConnectException](#netsubscriptiondnsconnectexception)
            1. [ConnectStart](#netsubscriptiondnsconnectstart)
            1. [ConnectionExist](#netsubscriptiondnsconnectionexist)
            1. [MissingLocalAddress](#netsubscriptiondnsmissinglocaladdress)
            1. [Restart](#netsubscriptiondnsrestart)
            1. [SkippingPeer](#netsubscriptiondnsskippingpeer)
            1. [SocketAllocationException](#netsubscriptiondnssocketallocationexception)
            1. [Start](#netsubscriptiondnsstart)
            1. [SubscriptionFailed](#netsubscriptiondnssubscriptionfailed)
            1. [SubscriptionRunning](#netsubscriptiondnssubscriptionrunning)
            1. [SubscriptionWaiting](#netsubscriptiondnssubscriptionwaiting)
            1. [SubscriptionWaitingNewConnection](#netsubscriptiondnssubscriptionwaitingnewconnection)
            1. [TryConnectToPeer](#netsubscriptiondnstryconnecttopeer)
            1. [UnsupportedRemoteAddr](#netsubscriptiondnsunsupportedremoteaddr)
        1. __IPⓣ__
            1. [AllocateSocket](#netsubscriptionipallocatesocket)
            1. [ApplicationException](#netsubscriptionipapplicationexception)
            1. [CloseSocket](#netsubscriptionipclosesocket)
            1. [ConnectEnd](#netsubscriptionipconnectend)
            1. [ConnectException](#netsubscriptionipconnectexception)
            1. [ConnectStart](#netsubscriptionipconnectstart)
            1. [ConnectionExist](#netsubscriptionipconnectionexist)
            1. [MissingLocalAddress](#netsubscriptionipmissinglocaladdress)
            1. [Restart](#netsubscriptioniprestart)
            1. [SkippingPeer](#netsubscriptionipskippingpeer)
            1. [SocketAllocationException](#netsubscriptionipsocketallocationexception)
            1. [Start](#netsubscriptionipstart)
            1. [SubscriptionFailed](#netsubscriptionipsubscriptionfailed)
            1. [SubscriptionRunning](#netsubscriptionipsubscriptionrunning)
            1. [SubscriptionWaiting](#netsubscriptionipsubscriptionwaiting)
            1. [SubscriptionWaitingNewConnection](#netsubscriptionipsubscriptionwaitingnewconnection)
            1. [TryConnectToPeer](#netsubscriptioniptryconnecttopeer)
            1. [UnsupportedRemoteAddr](#netsubscriptionipunsupportedremoteaddr)
1. __NodeStateⓣ__
    1. [NodeAddBlock](#nodestatenodeaddblock)
    1. [NodeInitChainSelection](#nodestatenodeinitchainselection)
    1. [NodeKernelOnline](#nodestatenodekernelonline)
    1. [NodeReplays](#nodestatenodereplays)
    1. [NodeShutdown](#nodestatenodeshutdown)
    1. [NodeStartup](#nodestatenodestartup)
    1. [NodeTracingOnlineConfiguring](#nodestatenodetracingonlineconfiguring)
    1. [OpeningDbs](#nodestateopeningdbs)
1. __Reflectionⓣⓜ__
    1. [MetricsInfo](#reflectionmetricsinfo)
    1. [RememberLimiting](#reflectionrememberlimiting)
    1. [StartLimiting](#reflectionstartlimiting)
    1. [StopLimiting](#reflectionstoplimiting)
    1. [TracerConfigInfo](#reflectiontracerconfiginfo)
    1. [TracerConsistencyWarnings](#reflectiontracerconsistencywarnings)
    1. [TracerInfo](#reflectiontracerinfo)
    1. [UnknownNamespace](#reflectionunknownnamespace)
1. [Resources](#resources)
1. __Shutdownⓣ__
    1. [Abnormal](#shutdownabnormal)
    1. [ArmedAt](#shutdownarmedat)
    1. [Requested](#shutdownrequested)
    1. [Requesting](#shutdownrequesting)
    1. [UnexpectedInput](#shutdownunexpectedinput)
1. __Startupⓣⓜ__
    1. [BlockForgingBlockTypeMismatch](#startupblockforgingblocktypemismatch)
    1. [BlockForgingUpdate](#startupblockforgingupdate)
    1. [Byron](#startupbyron)
    1. [Common](#startupcommon)
    1. [DBValidation](#startupdbvalidation)
    1. __DiffusionInitⓣ__
        1. [ConfiguringLocalSocket](#startupdiffusioninitconfiguringlocalsocket)
        1. [ConfiguringServerSocket](#startupdiffusioninitconfiguringserversocket)
        1. [CreateSystemdSocketForSnocketPath](#startupdiffusioninitcreatesystemdsocketforsnocketpath)
        1. [CreatedLocalSocket](#startupdiffusioninitcreatedlocalsocket)
        1. [CreatingServerSocket](#startupdiffusioninitcreatingserversocket)
        1. [DiffusionErrored](#startupdiffusioninitdiffusionerrored)
        1. [ListeningLocalSocket](#startupdiffusioninitlisteninglocalsocket)
        1. [ListeningServerSocket](#startupdiffusioninitlisteningserversocket)
        1. [LocalSocketUp](#startupdiffusioninitlocalsocketup)
        1. [RunLocalServer](#startupdiffusioninitrunlocalserver)
        1. [RunServer](#startupdiffusioninitrunserver)
        1. [ServerSocketUp](#startupdiffusioninitserversocketup)
        1. [SystemdSocketConfiguration](#startupdiffusioninitsystemdsocketconfiguration)
        1. [UnsupportedLocalSystemdSocket](#startupdiffusioninitunsupportedlocalsystemdsocket)
        1. [UnsupportedReadySocketCase](#startupdiffusioninitunsupportedreadysocketcase)
        1. [UsingSystemdSocket](#startupdiffusioninitusingsystemdsocket)
    1. [Info](#startupinfo)
    1. [Network](#startupnetwork)
    1. [NetworkConfig](#startupnetworkconfig)
    1. [NetworkConfigLegacy](#startupnetworkconfiglegacy)
    1. [NetworkConfigUpdate](#startupnetworkconfigupdate)
    1. [NetworkConfigUpdateError](#startupnetworkconfigupdateerror)
    1. [NetworkConfigUpdateUnsupported](#startupnetworkconfigupdateunsupported)
    1. [NetworkMagic](#startupnetworkmagic)
    1. [NonP2PWarning](#startupnonp2pwarning)
    1. [P2PInfo](#startupp2pinfo)
    1. [ShelleyBased](#startupshelleybased)
    1. [SocketConfigError](#startupsocketconfigerror)
    1. [Time](#startuptime)
    1. [WarningDevelopmentNodeToClientVersions](#startupwarningdevelopmentnodetoclientversions)
    1. [WarningDevelopmentNodeToNodeVersions](#startupwarningdevelopmentnodetonodeversions)
1. __StateQueryServerⓣ__
    1. __Receive__
        1. [Acquire](#statequeryserverreceiveacquire)
        1. [Acquired](#statequeryserverreceiveacquired)
        1. [Done](#statequeryserverreceivedone)
        1. [Failure](#statequeryserverreceivefailure)
        1. [Query](#statequeryserverreceivequery)
        1. [ReAcquire](#statequeryserverreceivereacquire)
        1. [Release](#statequeryserverreceiverelease)
        1. [Result](#statequeryserverreceiveresult)
    1. __Send__
        1. [Acquire](#statequeryserversendacquire)
        1. [Acquired](#statequeryserversendacquired)
        1. [Done](#statequeryserversenddone)
        1. [Failure](#statequeryserversendfailure)
        1. [Query](#statequeryserversendquery)
        1. [ReAcquire](#statequeryserversendreacquire)
        1. [Release](#statequeryserversendrelease)
        1. [Result](#statequeryserversendresult)
1. __TxSubmission__
    1. __Localⓣⓢ__
        1. __Receive__
            1. [AcceptTx](#txsubmissionlocalreceiveaccepttx)
            1. [Done](#txsubmissionlocalreceivedone)
            1. [RejectTx](#txsubmissionlocalreceiverejecttx)
            1. [SubmitTx](#txsubmissionlocalreceivesubmittx)
        1. __Send__
            1. [AcceptTx](#txsubmissionlocalsendaccepttx)
            1. [Done](#txsubmissionlocalsenddone)
            1. [RejectTx](#txsubmissionlocalsendrejecttx)
            1. [SubmitTx](#txsubmissionlocalsendsubmittx)
    1. __LocalServerⓣⓢ__
        1. [ReceivedTx](#txsubmissionlocalserverreceivedtx)
    1. __MonitorClientⓣⓢ__
        1. __Receive__
            1. [Acquire](#txsubmissionmonitorclientreceiveacquire)
            1. [Acquired](#txsubmissionmonitorclientreceiveacquired)
            1. [AwaitAcquire](#txsubmissionmonitorclientreceiveawaitacquire)
            1. [Done](#txsubmissionmonitorclientreceivedone)
            1. [GetSizes](#txsubmissionmonitorclientreceivegetsizes)
            1. [HasTx](#txsubmissionmonitorclientreceivehastx)
            1. [NextTx](#txsubmissionmonitorclientreceivenexttx)
            1. [Release](#txsubmissionmonitorclientreceiverelease)
            1. [ReplyGetSizes](#txsubmissionmonitorclientreceivereplygetsizes)
            1. [ReplyHasTx](#txsubmissionmonitorclientreceivereplyhastx)
            1. [ReplyNextTx](#txsubmissionmonitorclientreceivereplynexttx)
        1. __Send__
            1. [Acquire](#txsubmissionmonitorclientsendacquire)
            1. [Acquired](#txsubmissionmonitorclientsendacquired)
            1. [AwaitAcquire](#txsubmissionmonitorclientsendawaitacquire)
            1. [Done](#txsubmissionmonitorclientsenddone)
            1. [GetSizes](#txsubmissionmonitorclientsendgetsizes)
            1. [HasTx](#txsubmissionmonitorclientsendhastx)
            1. [NextTx](#txsubmissionmonitorclientsendnexttx)
            1. [Release](#txsubmissionmonitorclientsendrelease)
            1. [ReplyGetSizes](#txsubmissionmonitorclientsendreplygetsizes)
            1. [ReplyHasTx](#txsubmissionmonitorclientsendreplyhastx)
            1. [ReplyNextTx](#txsubmissionmonitorclientsendreplynexttx)
    1. __Remoteⓣⓢ__
        1. __Receive__
            1. [Done](#txsubmissionremotereceivedone)
            1. [MsgInit](#txsubmissionremotereceivemsginit)
            1. [ReplyTxIds](#txsubmissionremotereceivereplytxids)
            1. [ReplyTxs](#txsubmissionremotereceivereplytxs)
            1. [RequestTxIds](#txsubmissionremotereceiverequesttxids)
            1. [RequestTxs](#txsubmissionremotereceiverequesttxs)
        1. __Send__
            1. [Done](#txsubmissionremotesenddone)
            1. [MsgInit](#txsubmissionremotesendmsginit)
            1. [ReplyTxIds](#txsubmissionremotesendreplytxids)
            1. [ReplyTxs](#txsubmissionremotesendreplytxs)
            1. [RequestTxIds](#txsubmissionremotesendrequesttxids)
            1. [RequestTxs](#txsubmissionremotesendrequesttxs)
    1. __TxInboundⓣⓜ__
        1. [CanRequestMoreTxs](#txsubmissiontxinboundcanrequestmoretxs)
        1. [CannotRequestMoreTxs](#txsubmissiontxinboundcannotrequestmoretxs)
        1. [Collected](#txsubmissiontxinboundcollected)
        1. [Processed](#txsubmissiontxinboundprocessed)
        1. [Terminated](#txsubmissiontxinboundterminated)
    1. __TxOutboundⓣⓢ__
        1. [ControlMessage](#txsubmissiontxoutboundcontrolmessage)
        1. [RecvMsgRequest](#txsubmissiontxoutboundrecvmsgrequest)
        1. [SendMsgReply](#txsubmissiontxoutboundsendmsgreply)
1. __Versionⓣⓢ__
    1. [NodeVersion](#versionnodeversion)

### [Metrics](#metrics)

1. __Forge__
    1. [DelegMapSize](#forgedelegmapsize)
    1. [UtxoSize](#forgeutxosize)
1. __Mem__
    1. [resident](#memresident)
1. __RTS__
    1. [alloc](#rtsalloc)
    1. [gcHeapBytes](#rtsgcheapbytes)
    1. [gcLiveBytes](#rtsgclivebytes)
    1. [gcMajorNum](#rtsgcmajornum)
    1. [gcMinorNum](#rtsgcminornum)
    1. [gcticks](#rtsgcticks)
    1. [mutticks](#rtsmutticks)
    1. [threads](#rtsthreads)
1. __Stat__
    1. [cputicks](#statcputicks)
    1. [fsRd](#statfsrd)
    1. [fsWr](#statfswr)
    1. [netRd](#statnetrd)
    1. [netWr](#statnetwr)
1. __SuppressedMessages__
    1. ____
        1. ____
            1. [](#suppressedmessages)
1. [aboutToLeadSlotLast](#abouttoleadslotlast)
1. [adoptedOwnBlockSlotLast](#adoptedownblockslotlast)
1. [adoptionThreadDied](#adoptionthreaddied)
1. [blockContext](#blockcontext)
1. [blockFromFuture](#blockfromfuture)
1. [blockNum](#blocknum)
1. [blockReplayProgress](#blockreplayprogress)
1. __blockfetchclient__
    1. [blockdelay](#blockfetchclientblockdelay)
    1. __blockdelay__
        1. [cdfFive](#blockfetchclientblockdelaycdffive)
        1. [cdfOne](#blockfetchclientblockdelaycdfone)
        1. [cdfThree](#blockfetchclientblockdelaycdfthree)
    1. [blocksize](#blockfetchclientblocksize)
    1. [lateblocks](#blockfetchclientlateblocks)
1. [blocksForged](#blocksforged)
1. [cardano_build_info](#cardano_build_info)
1. [cardano_version_major](#cardano_version_major)
1. [cardano_version_minor](#cardano_version_minor)
1. [cardano_version_patch](#cardano_version_patch)
1. [connectedPeers](#connectedpeers)
1. __connectionManager__
    1. [duplexConns](#connectionmanagerduplexconns)
    1. [duplexConns](#connectionmanagerduplexconns)
    1. [fullDuplexConns](#connectionmanagerfullduplexconns)
    1. [fullDuplexConns](#connectionmanagerfullduplexconns)
    1. [inboundConns](#connectionmanagerinboundconns)
    1. [inboundConns](#connectionmanagerinboundconns)
    1. [outboundConns](#connectionmanageroutboundconns)
    1. [outboundConns](#connectionmanageroutboundconns)
    1. [unidirectionalConns](#connectionmanagerunidirectionalconns)
    1. [unidirectionalConns](#connectionmanagerunidirectionalconns)
1. [couldNotForgeSlotLast](#couldnotforgeslotlast)
1. [currentKESPeriod](#currentkesperiod)
1. [currentKESPeriod](#currentkesperiod)
1. [density](#density)
1. [epoch](#epoch)
1. [forgedInvalidSlotLast](#forgedinvalidslotlast)
1. [forgedSlotLast](#forgedslotlast)
1. [forging_enabled](#forging_enabled)
1. [haskell_compiler_major](#haskell_compiler_major)
1. [haskell_compiler_minor](#haskell_compiler_minor)
1. [headersServed](#headersserved)
1. [headersServed](#headersserved)
1. __headersServed__
    1. [falling](#headersservedfalling)
    1. [falling](#headersservedfalling)
1. __inboundGovernor__
    1. [Cold](#inboundgovernorcold)
    1. [Cold](#inboundgovernorcold)
    1. [Hot](#inboundgovernorhot)
    1. [Hot](#inboundgovernorhot)
    1. [Idle](#inboundgovernoridle)
    1. [Idle](#inboundgovernoridle)
    1. [Warm](#inboundgovernorwarm)
    1. [Warm](#inboundgovernorwarm)
1. [ledgerState](#ledgerstate)
1. [ledgerView](#ledgerview)
1. __localInboundGovernor__
    1. [cold](#localinboundgovernorcold)
    1. [cold](#localinboundgovernorcold)
    1. [hot](#localinboundgovernorhot)
    1. [hot](#localinboundgovernorhot)
    1. [idle](#localinboundgovernoridle)
    1. [idle](#localinboundgovernoridle)
    1. [warm](#localinboundgovernorwarm)
    1. [warm](#localinboundgovernorwarm)
1. [mempoolBytes](#mempoolbytes)
1. [nodeCannotForge](#nodecannotforge)
1. [nodeCannotForge](#nodecannotforge)
1. [nodeIsLeader](#nodeisleader)
1. [nodeIsLeader](#nodeisleader)
1. [nodeNotLeader](#nodenotleader)
1. [notAdoptedSlotLast](#notadoptedslotlast)
1. [operationalCertificateExpiryKESPeriod](#operationalcertificateexpirykesperiod)
1. [operationalCertificateExpiryKESPeriod](#operationalcertificateexpirykesperiod)
1. [operationalCertificateStartKESPeriod](#operationalcertificatestartkesperiod)
1. [operationalCertificateStartKESPeriod](#operationalcertificatestartkesperiod)
1. __peerSelection__
    1. [ActiveBigLedgerPeers](#peerselectionactivebigledgerpeers)
    1. [ActiveBigLedgerPeersDemotions](#peerselectionactivebigledgerpeersdemotions)
    1. [ActiveBootstrapPeers](#peerselectionactivebootstrappeers)
    1. [ActiveBootstrapPeersDemotions](#peerselectionactivebootstrappeersdemotions)
    1. [ActiveLocalRootPeers](#peerselectionactivelocalrootpeers)
    1. [ActiveLocalRootPeersDemotions](#peerselectionactivelocalrootpeersdemotions)
    1. [ActiveNonRootPeers](#peerselectionactivenonrootpeers)
    1. [ActiveNonRootPeersDemotions](#peerselectionactivenonrootpeersdemotions)
    1. [ActivePeers](#peerselectionactivepeers)
    1. [ActivePeersDemotions](#peerselectionactivepeersdemotions)
    1. [Cold](#peerselectioncold)
    1. [ColdBigLedgerPeers](#peerselectioncoldbigledgerpeers)
    1. [ColdBigLedgerPeersPromotions](#peerselectioncoldbigledgerpeerspromotions)
    1. [ColdBootstrapPeersPromotions](#peerselectioncoldbootstrappeerspromotions)
    1. [ColdNonRootPeersPromotions](#peerselectioncoldnonrootpeerspromotions)
    1. [ColdPeersPromotions](#peerselectioncoldpeerspromotions)
    1. [EstablishedBigLedgerPeers](#peerselectionestablishedbigledgerpeers)
    1. [EstablishedBootstrapPeers](#peerselectionestablishedbootstrappeers)
    1. [EstablishedLocalRootPeers](#peerselectionestablishedlocalrootpeers)
    1. [EstablishedNonRootPeers](#peerselectionestablishednonrootpeers)
    1. [EstablishedPeers](#peerselectionestablishedpeers)
    1. [Hot](#peerselectionhot)
    1. [HotBigLedgerPeers](#peerselectionhotbigledgerpeers)
    1. [KnownBigLedgerPeers](#peerselectionknownbigledgerpeers)
    1. [KnownBootstrapPeers](#peerselectionknownbootstrappeers)
    1. [KnownLocalRootPeers](#peerselectionknownlocalrootpeers)
    1. [KnownNonRootPeers](#peerselectionknownnonrootpeers)
    1. [KnownPeers](#peerselectionknownpeers)
    1. [LocalRoots](#peerselectionlocalroots)
    1. [RootPeers](#peerselectionrootpeers)
    1. [Warm](#peerselectionwarm)
    1. [WarmBigLedgerPeers](#peerselectionwarmbigledgerpeers)
    1. [WarmBigLedgerPeersDemotions](#peerselectionwarmbigledgerpeersdemotions)
    1. [WarmBigLedgerPeersPromotions](#peerselectionwarmbigledgerpeerspromotions)
    1. [WarmBootstrapPeersDemotions](#peerselectionwarmbootstrappeersdemotions)
    1. [WarmBootstrapPeersPromotions](#peerselectionwarmbootstrappeerspromotions)
    1. [WarmLocalRootPeersPromotions](#peerselectionwarmlocalrootpeerspromotions)
    1. [WarmNonRootPeersDemotions](#peerselectionwarmnonrootpeersdemotions)
    1. [WarmNonRootPeersPromotions](#peerselectionwarmnonrootpeerspromotions)
    1. [WarmPeersDemotions](#peerselectionwarmpeersdemotions)
    1. [WarmPeersPromotions](#peerselectionwarmpeerspromotions)
    1. __churn__
        1. [DecreasedActiveBigLedgerPeers](#peerselectionchurndecreasedactivebigledgerpeers)
        1. [DecreasedActivePeers](#peerselectionchurndecreasedactivepeers)
        1. [DecreasedEstablishedBigLedgerPeers](#peerselectionchurndecreasedestablishedbigledgerpeers)
        1. [DecreasedEstablishedPeers](#peerselectionchurndecreasedestablishedpeers)
        1. [DecreasedKnownBigLedgerPeers](#peerselectionchurndecreasedknownbigledgerpeers)
        1. [DecreasedKnownPeers](#peerselectionchurndecreasedknownpeers)
        1. [IncreasedActiveBigLedgerPeers](#peerselectionchurnincreasedactivebigledgerpeers)
        1. [IncreasedActivePeers](#peerselectionchurnincreasedactivepeers)
        1. [IncreasedEstablishedBigLedgerPeers](#peerselectionchurnincreasedestablishedbigledgerpeers)
        1. [IncreasedEstablishedPeers](#peerselectionchurnincreasedestablishedpeers)
        1. [IncreasedKnownBigLedgerPeers](#peerselectionchurnincreasedknownbigledgerpeers)
        1. [IncreasedKnownPeers](#peerselectionchurnincreasedknownpeers)
1. [peersFromNodeKernel](#peersfromnodekernel)
1. [remainingKESPeriods](#remainingkesperiods)
1. [remainingKESPeriods](#remainingkesperiods)
1. __served__
    1. [block](#servedblock)
1. [slotInEpoch](#slotinepoch)
1. [slotIsImmutable](#slotisimmutable)
1. [slotNum](#slotnum)
1. [slotsMissed](#slotsmissed)
1. __submissions__
    1. [accepted](#submissionsaccepted)
    1. [rejected](#submissionsrejected)
    1. [submitted](#submissionssubmitted)
1. [systemStartTime](#systemstarttime)
1. [txsInMempool](#txsinmempool)
1. [txsProcessedNum](#txsprocessednum)

### [Datapoints](#datapoints)

1. [NodeInfo](#nodeinfo)
1. [NodeStartupInfo](#nodestartupinfo)

### [Configuration](#configuration)



## Trace Messages

### BlockFetch.Client.AcknowledgedFetchRequest


> Mark the point when the fetch client picks up the request added by the block fetch decision thread. Note that this event can happen fewer times than the 'AddedFetchRequest' due to fetch request merging.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Client.AddedFetchRequest


> The block fetch decision thread has added a new fetch instruction consisting of one or more individual request ranges.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Client.ClientMetrics




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Client.ClientTerminating


> The client is terminating.  Log the number of outstanding requests.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### BlockFetch.Client.CompletedBlockFetch




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`
Limiter `BlockFetch.Client.CompletedBlockFetch` with frequency `2.0`

### BlockFetch.Client.CompletedFetchBatch


> Mark the successful end of receiving a streaming batch of blocks.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Client.RejectedFetchBatch


> If the other peer rejects our request then we have this event instead of 'StartedFetchBatch' and 'CompletedFetchBatch'.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Client.SendFetchRequest


> Mark the point when fetch request for a fragment is actually sent over the wire.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Client.StartedFetchBatch


> Mark the start of receiving a streaming batch of blocks. This will be followed by one or more 'CompletedBlockFetch' and a final 'CompletedFetchBatch'


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Decision.Accept


> Throughout the decision making process we accumulate reasons to decline to fetch any blocks. This message carries the intermediate and final results.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### BlockFetch.Decision.Decline


> Throughout the decision making process we accumulate reasons to decline to fetch any blocks. This message carries the intermediate and final results.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### BlockFetch.Decision.EmptyPeersFetch


> Throughout the decision making process we accumulate reasons to decline to fetch any blocks. This message carries the intermediate and final results.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### BlockFetch.Remote.Receive.BatchDone


> End of block streaming.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Receive.Block


> Stream a single block.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Receive.ClientDone


> Client termination message.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Receive.NoBlocks


> Respond that there are no blocks.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Receive.RequestRange


> Request range of blocks.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Receive.StartBatch


> Start block streaming.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Send.BatchDone


> End of block streaming.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Send.Block


> Stream a single block.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Send.ClientDone


> Client termination message.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Send.NoBlocks


> Respond that there are no blocks.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Send.RequestRange


> Request range of blocks.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Send.StartBatch


> Start block streaming.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Serialised.Receive.BatchDone


> End of block streaming.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Serialised.Receive.Block


> Stream a single block.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Serialised.Receive.ClientDone


> Client termination message.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Serialised.Receive.NoBlocks


> Respond that there are no blocks.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Serialised.Receive.RequestRange


> Request range of blocks.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Serialised.Receive.StartBatch


> Start block streaming.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Serialised.Send.BatchDone


> End of block streaming.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Serialised.Send.Block


> Stream a single block.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Serialised.Send.ClientDone


> Client termination message.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Serialised.Send.NoBlocks


> Respond that there are no blocks.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Serialised.Send.RequestRange


> Request range of blocks.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Remote.Serialised.Send.StartBatch


> Start block streaming.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockFetch.Server.SendBlock


> The server sent a block to the peer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### BlockchainTime.CurrentSlotUnknown


> Current slot is not yet known
>  This happens when the tip of our current chain is so far in the past that we cannot translate the current wallclock to a slot number, typically during syncing. Until the current slot number is known, we cannot produce blocks. Seeing this message during syncing therefore is normal and to be expected.
>  We record the current time (the time we tried to translate to a 'SlotNo') as well as the 'PastHorizonException', which provides detail on the bounds between which we /can/ do conversions. The distance between the current time and the upper bound should rapidly decrease with consecutive 'CurrentSlotUnknown' messages during syncing.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### BlockchainTime.StartTimeInTheFuture


> The start time of the blockchain time is in the future
>  We have to block (for 'NominalDiffTime') until that time comes.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### BlockchainTime.SystemClockMovedBack


> The system clock moved back an acceptable time span, e.g., because of an NTP sync.
>  The system clock moved back such that the new current slot would be smaller than the previous one. If this is within the configured limit, we trace this warning but *do not change the current slot*. The current slot never decreases, but the current slot may stay the same longer than expected.
>  When the system clock moved back more than the configured limit, we shut down with a fatal exception.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### ChainDB.AddBlockEvent.AddBlockValidation.CandidateContainsFutureBlocks


> An event traced during validating performed while adding a block. Candidate contains headers from the future which do no exceed the clock skew.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.AddBlockEvent.AddBlockValidation.CandidateContainsFutureBlocksExceedingClockSkew


> An event traced during validating performed while adding a block. Candidate contains headers from the future which exceed the clock skew.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.AddBlockEvent.AddBlockValidation.InvalidBlock


> An event traced during validating performed while adding a block. A point was found to be invalid.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.AddBlockEvent.AddBlockValidation.UpdateLedgerDb




Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.AddBlockEvent.AddBlockValidation.ValidCandidate


> An event traced during validating performed while adding a block. A candidate chain was valid.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`
Limiter `ChainDB.AddBlockEvent.AddBlockValidation.ValidCandidate` with frequency `2.0`

### ChainDB.AddBlockEvent.AddedBlockToQueue


> The block was added to the queue and will be added to the ChainDB by the background thread. The size of the queue is included..


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`
Limiter `ChainDB.AddBlockEvent.AddedBlockToQueue` with frequency `2.0`

### ChainDB.AddBlockEvent.AddedBlockToVolatileDB


> A block was added to the Volatile DB


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`
Limiter `ChainDB.AddBlockEvent.AddedBlockToVolatileDB` with frequency `2.0`

### ChainDB.AddBlockEvent.AddedReprocessLoEBlocksToQueue




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.AddBlockEvent.AddedToCurrentChain


> The new block fits onto the current chain (first fragment) and we have successfully used it to extend our (new) current chain (second fragment).


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.AddBlockEvent.BlockInTheFuture


> The block is from the future, i.e., its slot number is greater than the current slot (the second argument).


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.AddBlockEvent.ChainSelectionForFutureBlock


> Run chain selection for a block that was previously from the future. This is done for all blocks from the future each time a new block is added.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.AddBlockEvent.ChainSelectionLoEDebug




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.AddBlockEvent.ChangingSelection


> The new block fits onto the current chain (first fragment) and we have successfully used it to extend our (new) current chain (second fragment).


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.AddBlockEvent.IgnoreBlockAlreadyInVolatileDB


> A block that is already in the Volatile DB was ignored.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.AddBlockEvent.IgnoreBlockOlderThanK


> A block with a 'BlockNo' more than @k@ back than the current tip was ignored.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.AddBlockEvent.IgnoreInvalidBlock


> A block that is invalid was ignored.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.AddBlockEvent.PipeliningEvent.OutdatedTentativeHeader


> We selected a new (better) chain, which cleared the previous tentative header.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.AddBlockEvent.PipeliningEvent.SetTentativeHeader


> A new tentative header got set


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.AddBlockEvent.PipeliningEvent.TrapTentativeHeader


> The body of tentative block turned out to be invalid.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.AddBlockEvent.PoppedBlockFromQueue




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.AddBlockEvent.PoppedReprocessLoEBlocksFromQueue




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.AddBlockEvent.StoreButDontChange


> The block fits onto some fork, we'll try to switch to that fork (if it is preferable to our chain).


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.AddBlockEvent.SwitchedToAFork


> The new block fits onto some fork and we have switched to that fork (second fragment), as it is preferable to our (previous) current chain (first fragment).


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.AddBlockEvent.TryAddToCurrentChain


> The block fits onto the current chain, we'll try to use it to extend our chain.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.AddBlockEvent.TrySwitchToAFork


> The block fits onto some fork, we'll try to switch to that fork (if it is preferable to our chain)


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.CopyToImmutableDBEvent.CopiedBlockToImmutableDB


> A block was successfully copied to the ImmDB.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`
Limiter `ChainDB.CopyToImmutableDBEvent.CopiedBlockToImmutableDB` with frequency `2.0`

### ChainDB.CopyToImmutableDBEvent.NoBlocksToCopyToImmutableDB


> There are no block to copy to the ImmDB.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.FollowerEvent.FollowerNewImmIterator


> The follower is in the 'FollowerInImmutableDB' state but the iterator is exhausted while the ImmDB has grown, so we open a new iterator to stream these blocks too.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.FollowerEvent.FollowerNoLongerInMem


> The follower was in 'FollowerInMem' state and is switched to the 'FollowerInImmutableDB' state.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.FollowerEvent.FollowerSwitchToMem


> The follower was in the 'FollowerInImmutableDB' state and is switched to the 'FollowerInMem' state.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.FollowerEvent.NewFollower


> A new follower was created.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.GCEvent.PerformedGC


> A garbage collection for the given 'SlotNo' was performed.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.GCEvent.ScheduledGC


> A garbage collection for the given 'SlotNo' was scheduled to happen at the given time.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.ImmDbEvent.CacheEvent.CurrentChunkHit


> Current chunk found in the cache.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.ImmDbEvent.CacheEvent.PastChunkEvict


> The least recently used past chunk was evicted because the cache was full.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.ImmDbEvent.CacheEvent.PastChunkExpired




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.ImmDbEvent.CacheEvent.PastChunkHit


> Past chunk found in the cache


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.ImmDbEvent.CacheEvent.PastChunkMiss


> Past chunk was not found in the cache


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.ImmDbEvent.ChunkFileDoesntFit


> The hash of the last block in the previous epoch doesn't match the previous hash of the first block in the current epoch


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.ChunkValidation.InvalidChunkFile




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.ChunkValidation.InvalidPrimaryIndex




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.ChunkValidation.InvalidSecondaryIndex




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.ChunkValidation.MissingChunkFile




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.ChunkValidation.MissingPrimaryIndex




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.ChunkValidation.MissingSecondaryIndex




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.ChunkValidation.RewritePrimaryIndex




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.ChunkValidation.RewriteSecondaryIndex




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.ChunkValidation.StartedValidatingChunk




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.ChunkValidation.ValidatedChunk




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.DBAlreadyClosed




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.DBClosed


> Closing the immutable DB


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.DeletingAfter


> Delete after


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.ImmDbEvent.Migrating


> Performing a migration of the on-disk files.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.ImmDbEvent.NoValidLastLocation


> No valid last location was found


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ImmDbEvent.ValidatedLastLocation


> The last location was validatet


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.InitChainSelEvent.InitialChainSelected


> A garbage collection for the given 'SlotNo' was performed.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.InitChainSelEvent.StartedInitChainSelection


> A garbage collection for the given 'SlotNo' was scheduled to happen at the given time.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.InitChainSelEvent.Validation.CandidateContainsFutureBlocks


> An event traced during validating performed while adding a block. Candidate contains headers from the future which do no exceed the clock skew.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.InitChainSelEvent.Validation.CandidateContainsFutureBlocksExceedingClockSkew


> An event traced during validating performed while adding a block. Candidate contains headers from the future which exceed the clock skew.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.InitChainSelEvent.Validation.InvalidBlock


> An event traced during validating performed while adding a block. A point was found to be invalid.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.InitChainSelEvent.Validation.UpdateLedgerDb




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.InitChainSelEvent.Validation.ValidCandidate


> An event traced during validating performed while adding a block. A candidate chain was valid.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.IteratorEvent.BlockGCedFromVolatileDB


> A block is no longer in the VolatileDB and isn't in the ImmDB either; it wasn't part of the current chain.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.IteratorEvent.BlockMissingFromVolatileDB


> A block is no longer in the VolatileDB because it has been garbage collected. It might now be in the ImmDB if it was part of the current chain.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.IteratorEvent.BlockWasCopiedToImmutableDB


> A block that has been garbage collected from the VolatileDB is now found and streamed from the ImmDB.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.IteratorEvent.StreamFromBoth


> Stream from both the VolatileDB and the ImmDB.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.IteratorEvent.StreamFromImmutableDB


> Stream only from the ImmDB.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.IteratorEvent.StreamFromVolatileDB


> Stream only from the VolatileDB.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.IteratorEvent.SwitchBackToVolatileDB


> We have streamed one or more blocks from the ImmDB that were part of the VolatileDB when initialising the iterator. Now, we have to look back in the VolatileDB again because the ImmDB doesn't have the next block we're looking for.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.IteratorEvent.UnknownRangeRequested.ForkTooOld




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.IteratorEvent.UnknownRangeRequested.MissingBlock




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.LedgerEvent.DeletedSnapshot


> A snapshot was written to disk.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.LedgerEvent.InvalidSnapshot


> An on disk snapshot was skipped because it was invalid.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.LedgerEvent.TookSnapshot


> A snapshot was written to disk.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.LedgerReplay.ReplayFromGenesis


> There were no LedgerDB snapshots on disk, so we're replaying all blocks starting from Genesis against the initial ledger. The @replayTo@ parameter corresponds to the block at the tip of the ImmDB, i.e., the last block to replay.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.LedgerReplay.ReplayFromSnapshot


> There was a LedgerDB snapshot on disk corresponding to the given tip. We're replaying more recent blocks against it. The @replayTo@ parameter corresponds to the block at the tip of the ImmDB, i.e., the last block to replay.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.LedgerReplay.ReplayedBlock


> We replayed the given block (reference) on the genesis snapshot during the initialisation of the LedgerDB.
>  The @blockInfo@ parameter corresponds replayed block and the @replayTo@ parameter corresponds to the block at the tip of the ImmDB, i.e., the last block to replay.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.OpenEvent.ClosedDB


> The ChainDB was closed.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.OpenEvent.OpenedDB


> The ChainDB was opened.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.OpenEvent.OpenedImmutableDB


> The ImmDB was opened.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.OpenEvent.OpenedLgrDB


> The LedgerDB was opened.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.OpenEvent.OpenedVolatileDB


> The VolatileDB was opened.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.OpenEvent.StartedOpeningDB




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.OpenEvent.StartedOpeningImmutableDB




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.OpenEvent.StartedOpeningLgrDB




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.OpenEvent.StartedOpeningVolatileDB




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.ReplayBlock.LedgerReplay


> Counts block replays and calculates the percent.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainDB.VolatileDbEvent.BlockAlreadyHere


> A block was found to be already in the DB.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.VolatileDbEvent.DBAlreadyClosed


> When closing the DB it was found it is closed already.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.VolatileDbEvent.DBClosed


> Closing the volatile DB


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.VolatileDbEvent.InvalidFileNames


> Reports a list of invalid file paths.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainDB.VolatileDbEvent.Truncate


> Truncates a file up to offset because of the error.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainSync.Client.AccessingForecastHorizon


> The slot number, which was previously beyond the forecast horizon, has now entered it


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainSync.Client.DownloadedHeader


> While following a candidate chain, we rolled forward by downloading a header.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`
Limiter `ChainSync.Client.DownloadedHeader` with frequency `2.0`

### ChainSync.Client.Exception


> An exception was thrown by the Chain Sync Client.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainSync.Client.FoundIntersection


> We found an intersection between our chain fragment and the candidate's chain.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainSync.Client.GaveLoPToken


> May have added atoken to the LoP bucket of the peer


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainSync.Client.JumpResult


> Response to a jump offer (accept or reject)


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainSync.Client.JumpingInstructionIs


> The client got its next instruction


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainSync.Client.JumpingWaitingForNextInstruction


> The client is waiting for the next instruction


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainSync.Client.OfferJump


> Offering a jump to the remote peer


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainSync.Client.RolledBack


> While following a candidate chain, we rolled back to the given point.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainSync.Client.Termination


> The client has terminated.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### ChainSync.Client.ValidatedHeader


> The header has been validated


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainSync.Client.WaitingBeyondForecastHorizon


> The slot number is beyond the forecast horizon


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### ChainSync.Local.Receive.AwaitReply


> Acknowledge the request but require the consumer to wait for the next update. This means that the consumer is synced with the producer, and the producer is waiting for its own chain state to change.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Receive.Done


> We have to explain to the framework what our states mean, in terms of which party has agency in each state. 
>  Idle states are where it is for the client to send a message, busy states are where the server is expected to send a reply.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Receive.FindIntersect


> Ask the producer to try to find an improved intersection point between the consumer and producer's chains. The consumer sends a sequence of points and it is up to the producer to find the first intersection point on its chain and send it back to the consumer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Receive.IntersectFound


> The reply to the consumer about an intersection found. The consumer can decide weather to send more points. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Receive.IntersectNotFound


> The reply to the consumer that no intersection was found: none of the points the consumer supplied are on the producer chain. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Receive.RequestNext


> Request the next update from the producer. The response can be a roll forward, a roll back or wait.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Receive.RollBackward


> Tell the consumer to roll back to a given point on their chain. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Receive.RollForward


> Tell the consumer to extend their chain with the given header. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Send.AwaitReply


> Acknowledge the request but require the consumer to wait for the next update. This means that the consumer is synced with the producer, and the producer is waiting for its own chain state to change.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Send.Done


> We have to explain to the framework what our states mean, in terms of which party has agency in each state. 
>  Idle states are where it is for the client to send a message, busy states are where the server is expected to send a reply.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Send.FindIntersect


> Ask the producer to try to find an improved intersection point between the consumer and producer's chains. The consumer sends a sequence of points and it is up to the producer to find the first intersection point on its chain and send it back to the consumer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Send.IntersectFound


> The reply to the consumer about an intersection found. The consumer can decide weather to send more points. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Send.IntersectNotFound


> The reply to the consumer that no intersection was found: none of the points the consumer supplied are on the producer chain. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Send.RequestNext


> Request the next update from the producer. The response can be a roll forward, a roll back or wait.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Send.RollBackward


> Tell the consumer to roll back to a given point on their chain. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Local.Send.RollForward


> Tell the consumer to extend their chain with the given header. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Receive.AwaitReply


> Acknowledge the request but require the consumer to wait for the next update. This means that the consumer is synced with the producer, and the producer is waiting for its own chain state to change.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Receive.Done


> We have to explain to the framework what our states mean, in terms of which party has agency in each state. 
>  Idle states are where it is for the client to send a message, busy states are where the server is expected to send a reply.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Receive.FindIntersect


> Ask the producer to try to find an improved intersection point between the consumer and producer's chains. The consumer sends a sequence of points and it is up to the producer to find the first intersection point on its chain and send it back to the consumer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Receive.IntersectFound


> The reply to the consumer about an intersection found. The consumer can decide weather to send more points. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Receive.IntersectNotFound


> The reply to the consumer that no intersection was found: none of the points the consumer supplied are on the producer chain. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Receive.RequestNext


> Request the next update from the producer. The response can be a roll forward, a roll back or wait.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Receive.RollBackward


> Tell the consumer to roll back to a given point on their chain. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Receive.RollForward


> Tell the consumer to extend their chain with the given header. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Send.AwaitReply


> Acknowledge the request but require the consumer to wait for the next update. This means that the consumer is synced with the producer, and the producer is waiting for its own chain state to change.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Send.Done


> We have to explain to the framework what our states mean, in terms of which party has agency in each state. 
>  Idle states are where it is for the client to send a message, busy states are where the server is expected to send a reply.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Send.FindIntersect


> Ask the producer to try to find an improved intersection point between the consumer and producer's chains. The consumer sends a sequence of points and it is up to the producer to find the first intersection point on its chain and send it back to the consumer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Send.IntersectFound


> The reply to the consumer about an intersection found. The consumer can decide weather to send more points. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Send.IntersectNotFound


> The reply to the consumer that no intersection was found: none of the points the consumer supplied are on the producer chain. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Send.RequestNext


> Request the next update from the producer. The response can be a roll forward, a roll back or wait.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Send.RollBackward


> Tell the consumer to roll back to a given point on their chain. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Send.RollForward


> Tell the consumer to extend their chain with the given header. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Receive.AwaitReply


> Acknowledge the request but require the consumer to wait for the next update. This means that the consumer is synced with the producer, and the producer is waiting for its own chain state to change.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Receive.Done


> We have to explain to the framework what our states mean, in terms of which party has agency in each state. 
>  Idle states are where it is for the client to send a message, busy states are where the server is expected to send a reply.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Receive.FindIntersect


> Ask the producer to try to find an improved intersection point between the consumer and producer's chains. The consumer sends a sequence of points and it is up to the producer to find the first intersection point on its chain and send it back to the consumer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Receive.IntersectFound


> The reply to the consumer about an intersection found. The consumer can decide weather to send more points. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Receive.IntersectNotFound


> The reply to the consumer that no intersection was found: none of the points the consumer supplied are on the producer chain. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Receive.RequestNext


> Request the next update from the producer. The response can be a roll forward, a roll back or wait.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Receive.RollBackward


> Tell the consumer to roll back to a given point on their chain. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Receive.RollForward


> Tell the consumer to extend their chain with the given header. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Send.AwaitReply


> Acknowledge the request but require the consumer to wait for the next update. This means that the consumer is synced with the producer, and the producer is waiting for its own chain state to change.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Send.Done


> We have to explain to the framework what our states mean, in terms of which party has agency in each state. 
>  Idle states are where it is for the client to send a message, busy states are where the server is expected to send a reply.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Send.FindIntersect


> Ask the producer to try to find an improved intersection point between the consumer and producer's chains. The consumer sends a sequence of points and it is up to the producer to find the first intersection point on its chain and send it back to the consumer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Send.IntersectFound


> The reply to the consumer about an intersection found. The consumer can decide weather to send more points. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Send.IntersectNotFound


> The reply to the consumer that no intersection was found: none of the points the consumer supplied are on the producer chain. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Send.RequestNext


> Request the next update from the producer. The response can be a roll forward, a roll back or wait.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Send.RollBackward


> Tell the consumer to roll back to a given point on their chain. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.Remote.Serialised.Send.RollForward


> Tell the consumer to extend their chain with the given header. 
>  The message also tells the consumer about the head point of the producer.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.ServerBlock.Update


> A server read has occurred, either for an add block or a rollback


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### ChainSync.ServerHeader.Update


> A server read has occurred, either for an add block or a rollback


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Forge.Loop.AdoptedBlock


> We adopted the block we produced, we also trace the transactions  that were adopted.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.AdoptionThreadDied


> Block adoption thread died


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.BlockContext


> We found out to which block we are going to connect the block we are about  to forge.   We record the current slot number, the block number of the block to  connect to and its point.   Note that block number of the block we will try to forge is one more than  the recorded block number.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Forge.Loop.BlockFromFuture


> Leadership check failed: the current chain contains a block from a slot  /after/ the current slot   This can only happen if the system is under heavy load.   We record both the current slot number as well as the slot number of the  block at the tip of the chain.   See also <https://github.com/input-output-hk/ouroboros-network/issues/1462>


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.DidntAdoptBlock


> We did not adopt the block we produced, but the block was valid. We  must have adopted a block that another leader of the same slot produced  before we got the chance of adopting our own block. This is very rare,  this warrants a warning.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.ForgeStateUpdateError


> Updating the forge state failed.   For example, the KES key could not be evolved anymore.   We record the error returned by 'updateForgeState'.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.ForgeTickedLedgerState




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Forge.Loop.ForgedBlock


> We forged a block.
>   We record the current slot number, the point of the predecessor, the block  itself, and the total size of the mempool snapshot at the time we produced  the block (which may be significantly larger than the block, due to  maximum block size)
>   This will be followed by one of three messages:
>   * AdoptedBlock (normally)
>   * DidntAdoptBlock (rarely)
>   * ForgedInvalidBlock (hopefully never, this would indicate a bug)


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.ForgedInvalidBlock


> We forged a block that is invalid according to the ledger in the  ChainDB. This means there is an inconsistency between the mempool  validation and the ledger validation. This is a serious error!


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.ForgingMempoolSnapshot




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Forge.Loop.LedgerState


> We obtained a ledger state for the point of the block we want to  connect to   We record both the current slot number as well as the point of the block  we attempt to connect the new block to (that we requested the ledger  state for).


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Forge.Loop.LedgerView


> We obtained a ledger view for the current slot number   We record the current slot number.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Forge.Loop.NoLedgerState


> Leadership check failed: we were unable to get the ledger state for the  point of the block we want to connect to   This can happen if after choosing which block to connect to the node  switched to a different fork. We expect this to happen only rather  rarely, so this certainly merits a warning; if it happens a lot, that  merits an investigation.   We record both the current slot number as well as the point of the block  we attempt to connect the new block to (that we requested the ledger  state for).


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.NoLedgerView


> Leadership check failed: we were unable to get the ledger view for the  current slot number   This will only happen if there are many missing blocks between the tip of  our chain and the current slot.   We record also the failure returned by 'forecastFor'.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.NodeCannotForge


> We did the leadership check and concluded that we should lead and forge  a block, but cannot.   This should only happen rarely and should be logged with warning severity.   Records why we cannot forge a block.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.NodeIsLeader


> We did the leadership check and concluded we /are/ the leader
>   The node will soon forge; it is about to read its transactions from the  Mempool. This will be followed by ForgedBlock.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.NodeNotLeader


> We did the leadership check and concluded we are not the leader   We record the current slot number


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.SlotIsImmutable


> Leadership check failed: the tip of the ImmutableDB inhabits the  current slot   This might happen in two cases.    1. the clock moved backwards, on restart we ignored everything from the      VolatileDB since it's all in the future, and now the tip of the      ImmutableDB points to a block produced in the same slot we're trying      to produce a block in    2. k = 0 and we already adopted a block from another leader of the same      slot.   We record both the current slot number as well as the tip of the  ImmutableDB.  See also <https://github.com/input-output-hk/ouroboros-network/issues/1462>


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.StartLeadershipCheck


> Start of the leadership check.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.Loop.StartLeadershipCheckPlus


> We adopted the block we produced, we also trace the transactions  that were adopted.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.StateInfo


> kesStartPeriod 
> kesEndPeriod is kesStartPeriod + tpraosMaxKESEvo
> kesEvolution is the current evolution or /relative period/.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Forge.ThreadStats.ForgeThreadStats




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Mempool.AddedTx


> New, valid transaction that was added to the Mempool.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Mempool.ManuallyRemovedTxs


> Transactions that have been manually removed from the Mempool.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Mempool.RejectedTx


> New, invalid transaction thas was rejected and thus not added to the Mempool.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Mempool.RemoveTxs


> Previously valid transactions that are no longer valid because of changes in the ledger state. These transactions have been removed from the Mempool.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.AcceptPolicy.ConnectionHardLimit


> Hard rate limit reached, waiting until the number of connections drops below n.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.AcceptPolicy.ConnectionLimitResume




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.AcceptPolicy.ConnectionRateLimiting


> Rate limiting accepting connections, delaying next accept for given time, currently serving n connections.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Churn.ChurnCounters


> churn counters


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.Connect




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.ConnectError




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.ConnectionCleanup




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.ConnectionExists




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.ConnectionFailure




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.ConnectionHandler




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.ConnectionManagerCounters




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.ConnectionNotFound




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.ConnectionTimeWait




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.ConnectionTimeWaitDone




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.ForbiddenConnection




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.ForbiddenOperation




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.ImpossibleConnection




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.IncludeConnection




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.PruneConnections




Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.ConnectionManager.Local.Shutdown




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.State




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.TerminatedConnection




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.TerminatingConnection




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Local.UnexpectedlyFalseAssertion




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.ConnectionManager.Local.UnregisterConnection




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ConnectionManager.Remote.Connect




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ConnectionManager.Remote.ConnectError




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.ConnectionCleanup




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ConnectionManager.Remote.ConnectionExists




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.ConnectionFailure




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.ConnectionHandler




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.ConnectionManagerCounters




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.ConnectionNotFound




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ConnectionManager.Remote.ConnectionTimeWait




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ConnectionManager.Remote.ConnectionTimeWaitDone




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.ForbiddenConnection




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.ForbiddenOperation




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.ImpossibleConnection




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.IncludeConnection




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ConnectionManager.Remote.PruneConnections




Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.Shutdown




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.State




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.TerminatedConnection




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ConnectionManager.Remote.TerminatingConnection




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ConnectionManager.Remote.UnexpectedlyFalseAssertion




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ConnectionManager.Remote.UnregisterConnection




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ConnectionManager.Transition.Transition




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.DNSResolver.LookupAAAAError


> AAAA lookup failed with an error.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.DNSResolver.LookupAAAAResult


> Lookup AAAA result.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.DNSResolver.LookupAError


> A lookup failed with an error.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.DNSResolver.LookupAResult


> Lookup A result.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.DNSResolver.LookupException


> A DNS lookup exception occurred.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.DNSResolver.LookupIPv4First


> Returning IPv4 address first.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.DNSResolver.LookupIPv6First


> Returning IPv6 address first.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.ErrorPolicy.Local.AcceptException


> 'accept' threw an exception.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ErrorPolicy.Local.KeepSuspended


> Consumer was suspended until producer will resume.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ErrorPolicy.Local.LocalNodeError


> Caught a local exception.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ErrorPolicy.Local.ResumeConsumer


> Resume consumer.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ErrorPolicy.Local.ResumePeer


> Resume a peer (both consumer and producer).


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ErrorPolicy.Local.ResumeProducer


> Resume producer.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ErrorPolicy.Local.SuspendConsumer


> Suspending consumer.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ErrorPolicy.Local.SuspendPeer


> Suspending peer with a given exception.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ErrorPolicy.Local.UnhandledApplicationException


> An application threw an exception, which was not handled.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ErrorPolicy.Local.UnhandledConnectionException




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ErrorPolicy.Remote.AcceptException


> 'accept' threw an exception.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ErrorPolicy.Remote.KeepSuspended


> Consumer was suspended until producer will resume.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ErrorPolicy.Remote.LocalNodeError


> Caught a local exception.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ErrorPolicy.Remote.ResumeConsumer


> Resume consumer.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ErrorPolicy.Remote.ResumePeer


> Resume a peer (both consumer and producer).


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ErrorPolicy.Remote.ResumeProducer


> Resume producer.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.ErrorPolicy.Remote.SuspendConsumer


> Suspending consumer.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ErrorPolicy.Remote.SuspendPeer


> Suspending peer with a given exception.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ErrorPolicy.Remote.UnhandledApplicationException


> An application threw an exception, which was not handled.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.ErrorPolicy.Remote.UnhandledConnectionException




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Handshake.Local.Receive.AcceptVersion


> The remote end decides which version to use and sends chosen version.The server is allowed to modify version parameters.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Local.Receive.MsgQueryReply


> `MsgQueryReply` received as a response to a handshake query in  'MsgProposeVersions' and lists the supported versions.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Local.Receive.ProposeVersions


> Propose versions together with version parameters.  It must be encoded to a sorted list..


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Local.Receive.Refuse


> It refuses to run any version.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Local.Receive.ReplyVersions


> `MsgReplyVersions` received as a response to 'MsgProposeVersions'.  It is not supported to explicitly send this message. It can only be received as a copy of 'MsgProposeVersions' in a simultaneous open scenario.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Local.Send.AcceptVersion


> The remote end decides which version to use and sends chosen version.The server is allowed to modify version parameters.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Local.Send.MsgQueryReply


> `MsgQueryReply` received as a response to a handshake query in  'MsgProposeVersions' and lists the supported versions.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Local.Send.ProposeVersions


> Propose versions together with version parameters.  It must be encoded to a sorted list..


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Local.Send.Refuse


> It refuses to run any version.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Local.Send.ReplyVersions


> `MsgReplyVersions` received as a response to 'MsgProposeVersions'.  It is not supported to explicitly send this message. It can only be received as a copy of 'MsgProposeVersions' in a simultaneous open scenario.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Remote.Receive.AcceptVersion


> The remote end decides which version to use and sends chosen version.The server is allowed to modify version parameters.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Remote.Receive.MsgQueryReply


> `MsgQueryReply` received as a response to a handshake query in  'MsgProposeVersions' and lists the supported versions.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Remote.Receive.ProposeVersions


> Propose versions together with version parameters.  It must be encoded to a sorted list..


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Remote.Receive.Refuse


> It refuses to run any version.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Remote.Receive.ReplyVersions


> `MsgReplyVersions` received as a response to 'MsgProposeVersions'.  It is not supported to explicitly send this message. It can only be received as a copy of 'MsgProposeVersions' in a simultaneous open scenario.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Remote.Send.AcceptVersion


> The remote end decides which version to use and sends chosen version.The server is allowed to modify version parameters.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Remote.Send.MsgQueryReply


> `MsgQueryReply` received as a response to a handshake query in  'MsgProposeVersions' and lists the supported versions.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Remote.Send.ProposeVersions


> Propose versions together with version parameters.  It must be encoded to a sorted list..


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Remote.Send.Refuse


> It refuses to run any version.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Handshake.Remote.Send.ReplyVersions


> `MsgReplyVersions` received as a response to 'MsgProposeVersions'.  It is not supported to explicitly send this message. It can only be received as a copy of 'MsgProposeVersions' in a simultaneous open scenario.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.DemotedToColdRemote


> All mini-protocols terminated.  The boolean is true if this connection was not used by p2p-governor, and thus the connection will be terminated.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.DemotedToWarmRemote


> All mini-protocols terminated.  The boolean is true if this connection was not used by p2p-governor, and thus the connection will be terminated.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.Inactive




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.InboundGovernorCounters




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.InboundGovernorError




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.InboundGovernor.Local.MaturedConnections




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.MuxCleanExit




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.MuxErrored




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.NewConnection




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.PromotedToHotRemote




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.PromotedToWarmRemote




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.RemoteState




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.ResponderErrored




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.ResponderRestarted




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.ResponderStartFailure




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.InboundGovernor.Local.ResponderStarted




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.ResponderTerminated




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Local.UnexpectedlyFalseAssertion




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.InboundGovernor.Local.WaitIdleRemote




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.InboundGovernor.Remote.DemotedToColdRemote


> All mini-protocols terminated.  The boolean is true if this connection was not used by p2p-governor, and thus the connection will be terminated.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.InboundGovernor.Remote.DemotedToWarmRemote


> All mini-protocols terminated.  The boolean is true if this connection was not used by p2p-governor, and thus the connection will be terminated.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.InboundGovernor.Remote.Inactive




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.InboundGovernor.Remote.InboundGovernorCounters




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.InboundGovernor.Remote.InboundGovernorError




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.InboundGovernor.Remote.MaturedConnections




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.InboundGovernor.Remote.MuxCleanExit




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.InboundGovernor.Remote.MuxErrored




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.InboundGovernor.Remote.NewConnection




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.InboundGovernor.Remote.PromotedToHotRemote




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.InboundGovernor.Remote.PromotedToWarmRemote




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.InboundGovernor.Remote.RemoteState




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.InboundGovernor.Remote.ResponderErrored




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.InboundGovernor.Remote.ResponderRestarted




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.InboundGovernor.Remote.ResponderStartFailure




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.InboundGovernor.Remote.ResponderStarted




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.InboundGovernor.Remote.ResponderTerminated




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.InboundGovernor.Remote.UnexpectedlyFalseAssertion




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.InboundGovernor.Remote.WaitIdleRemote




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.InboundGovernor.Transition.Transition




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.KeepAliveClient


> A server read has occurred, either for an add block or a rollback


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.ChannelRecvEnd


> Channel receive end.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.ChannelRecvStart


> Channel receive start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.ChannelSendEnd


> Channel send end.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.ChannelSendStart


> Channel send start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.CleanExit


> Miniprotocol terminated cleanly.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Mux.Local.ExceptionExit


> Miniprotocol terminated with exception.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Mux.Local.HandshakeClientEnd


> Handshake client end.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.HandshakeClientError


> Handshake client error.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Mux.Local.HandshakeServerEnd


> Handshake server end.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.HandshakeServerError


> Handshake server error.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Mux.Local.HandshakeStart


> Handshake start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.RecvDeltaQObservation


> Bearer DeltaQ observation.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.RecvDeltaQSample


> Bearer DeltaQ sample.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.RecvEnd


> Bearer receive end.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.RecvHeaderEnd


> Bearer receive header end.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.RecvHeaderStart


> Bearer receive header start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.RecvStart


> Bearer receive start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.SDUReadTimeoutException


> Timed out reading SDU.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Mux.Local.SDUWriteTimeoutException


> Timed out writing SDU.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Mux.Local.SendEnd


> Bearer send end.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.SendStart


> Bearer send start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.Shutdown


> Mux shutdown.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.StartEagerly


> Eagerly started.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.StartOnDemand


> Preparing to start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.StartedOnDemand


> Started on demand.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.State


> State.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.Stopped


> Mux shutdown.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.Stopping


> Mux shutdown.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.TCPInfo


> TCPInfo.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Local.Terminating


> Terminating.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Mux.Remote.ChannelRecvEnd


> Channel receive end.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.ChannelRecvStart


> Channel receive start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.ChannelSendEnd


> Channel send end.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.ChannelSendStart


> Channel send start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.CleanExit


> Miniprotocol terminated cleanly.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Mux.Remote.ExceptionExit


> Miniprotocol terminated with exception.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Mux.Remote.HandshakeClientEnd


> Handshake client end.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Mux.Remote.HandshakeClientError


> Handshake client error.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Mux.Remote.HandshakeServerEnd


> Handshake server end.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.HandshakeServerError


> Handshake server error.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Mux.Remote.HandshakeStart


> Handshake start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.RecvDeltaQObservation


> Bearer DeltaQ observation.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.RecvDeltaQSample


> Bearer DeltaQ sample.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.RecvEnd


> Bearer receive end.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.RecvHeaderEnd


> Bearer receive header end.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.RecvHeaderStart


> Bearer receive header start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.RecvStart


> Bearer receive start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.SDUReadTimeoutException


> Timed out reading SDU.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Mux.Remote.SDUWriteTimeoutException


> Timed out writing SDU.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Mux.Remote.SendEnd


> Bearer send end.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.SendStart


> Bearer send start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.Shutdown


> Mux shutdown.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.StartEagerly


> Eagerly started.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.StartOnDemand


> Preparing to start.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.StartedOnDemand


> Started on demand.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.State


> State.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Mux.Remote.Stopped


> Mux shutdown.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.Stopping


> Mux shutdown.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.TCPInfo


> TCPInfo.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Mux.Remote.Terminating


> Terminating.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.PeerSelection.Actions.MonitoringError




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Actions.MonitoringResult




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.PeerSelection.Actions.StatusChangeFailure




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Actions.StatusChanged




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Counters.Counters


> Counters of selected peers


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Initiator.GovernorState




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.PeerSelection.Responder.GovernorState




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.PeerSelection.Selection.ChurnMode




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.ChurnWait




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.DebugState


> peer selection internal state


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.DemoteAsynchronous




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.DemoteHotDone


> target active, actual active, peer


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.DemoteHotFailed


> target active, actual active, peer, reason


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.DemoteHotPeers


> target active, actual active, selected peers


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.DemoteLocalAsynchronous




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.DemoteLocalHotPeers


> local per-group (target active, actual active), selected peers


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.DemoteWarmDone


> target established, actual established, peer


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.DemoteWarmFailed


> target established, actual established, peer, reason


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.DemoteWarmPeers


> target established, actual established, selected peers


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.ForgetColdPeers


> target known peers, actual known peers, selected peers


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.GossipRequests


> target known peers, actual known peers, peers available for gossip, peers selected for gossip


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.PeerSelection.Selection.GossipResults




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.PeerSelection.Selection.GovernorWakeup




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.LocalRootPeersChanged




Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.OutboundGovernorCriticalFailure


> Outbound Governor was killed unexpectedly


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PickInboundPeers


> An inbound connection was added to known set of outbound governor


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PromoteColdDone


> target active, actual active, selected peers


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PromoteColdFailed


> target established, actual established, peer, delay until next promotion, reason


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PromoteColdLocalPeers


> target local established, actual local established, selected peers


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PromoteColdPeers


> target established, actual established, selected peers


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PromoteWarmAborted




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PromoteWarmDone


> target active, actual active, peer


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PromoteWarmFailed


> target active, actual active, peer, reason


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PromoteWarmLocalPeers


> local per-group (target active, actual active), selected peers


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PromoteWarmPeers


> target active, actual active, selected peers


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PublicRootsFailure




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PublicRootsRequest




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.PublicRootsResults




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.PeerSelection.Selection.TargetsChanged




Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Peers.Ledger.DisabledLedgerPeers


> Trace for when getting peers from the ledger is disabled, that is DontUseLedger.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.Ledger.FallingBackToPublicRootPeers




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.Ledger.FetchingNewLedgerState


> Trace for fetching a new list of peers from the ledger. Int is the number of peers returned.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.Ledger.PickedPeer


> Trace for a peer picked with accumulated and relative stake of its pool.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.Ledger.PickedPeers


> Trace for the number of peers we wanted to pick and the list of peers picked.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.Ledger.RequestForPeers


> RequestForPeers (NumberOfPeers 1)


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.Ledger.ReusingLedgerState




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.Ledger.TraceLedgerPeersDomains




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.Ledger.TraceLedgerPeersFailure




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.Ledger.TraceLedgerPeersResult




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.Ledger.TraceUseLedgerAfter


> Trace UseLedgerAfter value.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.Ledger.WaitingOnRequest




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.List.PeersFromNodeKernel




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.LocalRoot.LocalRootDNSMap




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.LocalRoot.LocalRootDomains




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.LocalRoot.LocalRootError




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.LocalRoot.LocalRootFailure




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.LocalRoot.LocalRootGroups




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.LocalRoot.LocalRootReconfigured




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.LocalRoot.LocalRootResult




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.LocalRoot.LocalRootWaiting




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.PublicRoot.PublicRootDomains




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.PublicRoot.PublicRootFailure




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.PublicRoot.PublicRootRelayAccessPoint




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Peers.PublicRoot.PublicRootResult




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Server.Local.AcceptConnection




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Server.Local.AcceptError




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Server.Local.AcceptPolicy




Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Server.Local.Error




Severity:  `Critical`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Server.Local.Started




Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Server.Local.Stopped




Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Server.Remote.AcceptConnection




Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Net.Server.Remote.AcceptError




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Server.Remote.AcceptPolicy




Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Server.Remote.Error




Severity:  `Critical`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Server.Remote.Started




Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Server.Remote.Stopped




Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Net.Subscription.DNS.AllocateSocket


> Allocate socket to address.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Subscription.DNS.ApplicationException


> Application Exception occurred.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.CloseSocket


> Closed socket to address.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.ConnectEnd


> Connection Attempt end with destination and outcome.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.ConnectException


> Socket Allocation Exception with destination and the exception.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.ConnectStart


> Connection Attempt Start with destination.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.ConnectionExist


> Connection exists to destination.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.MissingLocalAddress


> Missing local address.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.Restart


> Restarting Subscription after duration with desired valency and current valency.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.SkippingPeer


> Skipping peer with address.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.SocketAllocationException


> Socket Allocation Exception with destination and the exception.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.Start


> Starting Subscription Worker with a valency.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Subscription.DNS.SubscriptionFailed


> Failed to start all required subscriptions.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.SubscriptionRunning


> Required subscriptions started.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Subscription.DNS.SubscriptionWaiting


> Waiting on address with active connections.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Subscription.DNS.SubscriptionWaitingNewConnection


> Waiting delay time before attempting a new connection.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.TryConnectToPeer


> Trying to connect to peer with address.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.DNS.UnsupportedRemoteAddr


> Unsupported remote target address.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.AllocateSocket


> Allocate socket to address.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Subscription.IP.ApplicationException


> Application Exception occurred.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.CloseSocket


> Closed socket to address.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.ConnectEnd


> Connection Attempt end with destination and outcome.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.ConnectException


> Socket Allocation Exception with destination and the exception.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.ConnectStart


> Connection Attempt Start with destination.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.ConnectionExist


> Connection exists to destination.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.MissingLocalAddress


> Missing local address.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.Restart


> Restarting Subscription after duration with desired valency and current valency.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.SkippingPeer


> Skipping peer with address.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.SocketAllocationException


> Socket Allocation Exception with destination and the exception.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.Start


> Starting Subscription Worker with a valency.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Subscription.IP.SubscriptionFailed


> Failed to start all required subscriptions.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.SubscriptionRunning


> Required subscriptions started.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Subscription.IP.SubscriptionWaiting


> Waiting on address with active connections.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Info`

### Net.Subscription.IP.SubscriptionWaitingNewConnection


> Waiting delay time before attempting a new connection.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.TryConnectToPeer


> Trying to connect to peer with address.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Net.Subscription.IP.UnsupportedRemoteAddr


> Unsupported remote target address.


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### NodeState.NodeAddBlock


> Applying block


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### NodeState.NodeInitChainSelection


> Performing initial chain selection


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### NodeState.NodeKernelOnline




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### NodeState.NodeReplays


> Replaying chain


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### NodeState.NodeShutdown


> Node shutting down


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### NodeState.NodeStartup


> Node startup


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### NodeState.NodeTracingOnlineConfiguring


> Tracing system came online, system configuring now


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### NodeState.OpeningDbs


> ChainDB components being opened


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Reflection.MetricsInfo


> Writes out numbers for metrics delivered.
> This internal message can't be filtered by the current configuration


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Reflection.RememberLimiting


> ^ This message remembers of ongoing frequency limiting, and gives the number of messages that has been suppressed
> This internal message can't be filtered by the current configuration


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Reflection.StartLimiting


> This message indicates the start of frequency limiting
> This internal message can't be filtered by the current configuration


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Reflection.StopLimiting


> This message indicates the stop of frequency limiting, and gives the number of messages that has been suppressed
> This internal message can't be filtered by the current configuration


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Reflection.TracerConfigInfo


> Trace the tracer configuration which is effectively used.
> This internal message can't be filtered by the current configuration


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Reflection.TracerConsistencyWarnings


> Tracer consistency check found errors.
> This internal message can't be filtered by the current configuration


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Reflection.TracerInfo


> Writes out tracers with metrics and silent tracers.
> This internal message can't be filtered by the current configuration


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Reflection.UnknownNamespace


> A value was queried for a namespaces from a tracer,which is unknown. This indicates a bug in the tracer implementation.
> This internal message can't be filtered by the current configuration


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Resources




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Shutdown.Abnormal


> non-isEOFerror shutdown request


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Shutdown.ArmedAt


> Setting up node shutdown at given slot / block.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Shutdown.Requested


> Node shutdown was requested.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Shutdown.Requesting


> Ringing the node shutdown doorbell


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Shutdown.UnexpectedInput


> Received shutdown request but found unexpected input in --shutdown-ipc FD: 


Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Startup.BlockForgingBlockTypeMismatch




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Startup.BlockForgingUpdate




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Startup.Byron


> _bibSystemStartTime_: 
> _bibSlotLength_: gives the length of a slot as time interval. 
> _bibEpochLength_: gives the number of slots which forms an epoch.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Startup.Common


> _biConfigPath_: is the path to the config in use. 
> _biProtocol_: is the name of the protocol, e.g. "Byron", "Shelley" or "Byron; Shelley". 
> _biVersion_: is the version of the node software running. 
> _biCommit_: is the commit revision of the software running. 
> _biNodeStartTime_: gives the time this node was started.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Startup.DBValidation




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Startup.DiffusionInit.ConfiguringLocalSocket


> ConfiguringLocalSocket


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.ConfiguringServerSocket


> ConfiguringServerSocket


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.CreateSystemdSocketForSnocketPath


> CreateSystemdSocketForSnocketPath


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.CreatedLocalSocket


> CreatedLocalSocket


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.CreatingServerSocket


> CreatingServerSocket


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.DiffusionErrored


> DiffusionErrored


Severity:  `Critical`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.ListeningLocalSocket


> ListeningLocalSocket


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.ListeningServerSocket


> ListeningServerSocket


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.LocalSocketUp


> LocalSocketUp


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.RunLocalServer


> RunLocalServer


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.RunServer


> RunServer


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.ServerSocketUp


> ServerSocketUp


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.SystemdSocketConfiguration


> SystemdSocketConfiguration


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.UnsupportedLocalSystemdSocket


> UnsupportedLocalSystemdSocket


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.UnsupportedReadySocketCase


> UnsupportedReadySocketCase


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.DiffusionInit.UsingSystemdSocket


> UsingSystemdSocket


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Info`

### Startup.Info




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Startup.Network


> _niAddresses_: IPv4 or IPv6 socket ready to accept connectionsor diffusion addresses. 
> _niDiffusionMode_: shows if the node runs only initiator or bothinitiator or responder node. 
> _niDnsProducers_: shows the list of domain names to subscribe to. 
> _niIpProducers_: shows the list of ip subscription addresses.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Startup.NetworkConfig




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Startup.NetworkConfigLegacy




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Startup.NetworkConfigUpdate




Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Startup.NetworkConfigUpdateError




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Startup.NetworkConfigUpdateUnsupported




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Startup.NetworkMagic




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Startup.NonP2PWarning




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Startup.P2PInfo




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Startup.ShelleyBased


> bisEra is the current era, e.g. "Shelley", "Allegra", "Mary" or "Alonzo". 
> _bisSystemStartTime_: 
> _bisSlotLength_: gives the length of a slot as time interval. 
> _bisEpochLength_: gives the number of slots which forms an epoch. 
> _bisSlotsPerKESPeriod_: gives the slots per KES period.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Startup.SocketConfigError




Severity:  `Error`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Startup.Time




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Startup.WarningDevelopmentNodeToClientVersions




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### Startup.WarningDevelopmentNodeToNodeVersions




Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### StateQueryServer.Receive.Acquire


> The client requests that the state as of a particular recent point on the server's chain (within K of the tip) be made available to query, and waits for confirmation or failure. 
>  From 'NodeToClient_V8' onwards if the point is not specified, current tip will be acquired.  For previous versions of the protocol 'point' must be given.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Receive.Acquired


> The server can confirm that it has the state at the requested point.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Receive.Done


> The client can terminate the protocol.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Receive.Failure


> The server can report that it cannot obtain the state for the requested point.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### StateQueryServer.Receive.Query


> The client can perform queries on the current acquired state.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Receive.ReAcquire


> This is like 'MsgAcquire' but for when the client already has a state. By moving to another state directly without a 'MsgRelease' it enables optimisations on the server side (e.g. moving to the state for the immediate next block). 
>  Note that failure to re-acquire is equivalent to 'MsgRelease', rather than keeping the exiting acquired state. 
>  From 'NodeToClient_V8' onwards if the point is not specified, current tip will be acquired.  For previous versions of the protocol 'point' must be given.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Receive.Release


> The client can instruct the server to release the state. This lets the server free resources.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Receive.Result


> The server must reply with the queries.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Send.Acquire


> The client requests that the state as of a particular recent point on the server's chain (within K of the tip) be made available to query, and waits for confirmation or failure. 
>  From 'NodeToClient_V8' onwards if the point is not specified, current tip will be acquired.  For previous versions of the protocol 'point' must be given.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Send.Acquired


> The server can confirm that it has the state at the requested point.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Send.Done


> The client can terminate the protocol.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Send.Failure


> The server can report that it cannot obtain the state for the requested point.


Severity:  `Warning`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### StateQueryServer.Send.Query


> The client can perform queries on the current acquired state.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Send.ReAcquire


> This is like 'MsgAcquire' but for when the client already has a state. By moving to another state directly without a 'MsgRelease' it enables optimisations on the server side (e.g. moving to the state for the immediate next block). 
>  Note that failure to re-acquire is equivalent to 'MsgRelease', rather than keeping the exiting acquired state. 
>  From 'NodeToClient_V8' onwards if the point is not specified, current tip will be acquired.  For previous versions of the protocol 'point' must be given.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Send.Release


> The client can instruct the server to release the state. This lets the server free resources.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### StateQueryServer.Send.Result


> The server must reply with the queries.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Local.Receive.AcceptTx


> The server can reply to inform the client that it has accepted the transaction.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Local.Receive.Done


> The client can terminate the protocol.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Local.Receive.RejectTx


> The server can reply to inform the client that it has rejected the transaction. A reason for the rejection is included.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Local.Receive.SubmitTx


> The client submits a single transaction and waits a reply.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Local.Send.AcceptTx


> The server can reply to inform the client that it has accepted the transaction.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Local.Send.Done


> The client can terminate the protocol.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Local.Send.RejectTx


> The server can reply to inform the client that it has rejected the transaction. A reason for the rejection is included.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Local.Send.SubmitTx


> The client submits a single transaction and waits a reply.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.LocalServer.ReceivedTx


> A transaction was received.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Receive.Acquire




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Receive.Acquired




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Receive.AwaitAcquire




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Receive.Done




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Receive.GetSizes




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Receive.HasTx




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Receive.NextTx




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Receive.Release




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Receive.ReplyGetSizes




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Receive.ReplyHasTx




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Receive.ReplyNextTx




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Send.Acquire




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Send.Acquired




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Send.AwaitAcquire




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Send.Done




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Send.GetSizes




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Send.HasTx




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Send.NextTx




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Send.Release




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Send.ReplyGetSizes




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Send.ReplyHasTx




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.MonitorClient.Send.ReplyNextTx




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Remote.Receive.Done


> Termination message, initiated by the client when the server is making a blocking call for more transaction identifiers.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Remote.Receive.MsgInit


> Client side hello message.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Remote.Receive.ReplyTxIds


> Reply with a list of transaction identifiers for available transactions, along with the size of each transaction. 
>  The list must not be longer than the maximum number requested. 
>  In the 'StTxIds' 'StBlocking' state the list must be non-empty while in the 'StTxIds' 'StNonBlocking' state the list may be empty. 
>  These transactions are added to the notional FIFO of outstanding transaction identifiers for the protocol. 
>  The order in which these transaction identifiers are returned must be the order in which they are submitted to the mempool, to preserve dependent transactions.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Remote.Receive.ReplyTxs


> Reply with the requested transactions, or implicitly discard.
> Transactions can become invalid between the time the transaction identifier was sent and the transaction being requested. Invalid (including committed) transactions do not need to be sent.
> Any transaction identifiers requested but not provided in this reply should be considered as if this peer had never announced them. (Note that this is no guarantee that the transaction is invalid, it may still be valid and available from another peer).


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Remote.Receive.RequestTxIds


> Request a non-empty list of transaction identifiers from the client, and confirm a number of outstanding transaction identifiers. 
>  With 'TokBlocking' this is a a blocking operation: the response will always have at least one transaction identifier, and it does not expect a prompt response: there is no timeout. This covers the case when there is nothing else to do but wait. For example this covers leaf nodes that rarely, if ever, create and submit a transaction. 
>  With 'TokNonBlocking' this is a non-blocking operation: the response may be an empty list and this does expect a prompt response. This covers high throughput use cases where we wish to pipeline, by interleaving requests for additional transaction identifiers with requests for transactions, which requires these requests not block. 
>  The request gives the maximum number of transaction identifiers that can be accepted in the response. This must be greater than zero in the 'TokBlocking' case. In the 'TokNonBlocking' case either the numbers acknowledged or the number requested must be non-zero. In either case, the number requested must not put the total outstanding over the fixed protocol limit. 
> The request also gives the number of outstanding transaction identifiers that can now be acknowledged. The actual transactions to acknowledge are known to the peer based on the FIFO order in which they were provided. 
>  There is no choice about when to use the blocking case versus the non-blocking case, it depends on whether there are any remaining unacknowledged transactions (after taking into account the ones acknowledged in this message): 
>  * The blocking case must be used when there are zero remaining   unacknowledged transactions. 
>  * The non-blocking case must be used when there are non-zero remaining   unacknowledged transactions.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Remote.Receive.RequestTxs


> Request one or more transactions corresponding to the given  transaction identifiers.  
>  While it is the responsibility of the replying peer to keep within pipelining in-flight limits, the sender must also cooperate by keeping the total requested across all in-flight requests within the limits. 
> It is an error to ask for transaction identifiers that were not previously announced (via 'MsgReplyTxIds'). 
> It is an error to ask for transaction identifiers that are not outstanding or that were already asked for.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Remote.Send.Done


> Termination message, initiated by the client when the server is making a blocking call for more transaction identifiers.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Remote.Send.MsgInit


> Client side hello message.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Remote.Send.ReplyTxIds


> Reply with a list of transaction identifiers for available transactions, along with the size of each transaction. 
>  The list must not be longer than the maximum number requested. 
>  In the 'StTxIds' 'StBlocking' state the list must be non-empty while in the 'StTxIds' 'StNonBlocking' state the list may be empty. 
>  These transactions are added to the notional FIFO of outstanding transaction identifiers for the protocol. 
>  The order in which these transaction identifiers are returned must be the order in which they are submitted to the mempool, to preserve dependent transactions.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Remote.Send.ReplyTxs


> Reply with the requested transactions, or implicitly discard.
> Transactions can become invalid between the time the transaction identifier was sent and the transaction being requested. Invalid (including committed) transactions do not need to be sent.
> Any transaction identifiers requested but not provided in this reply should be considered as if this peer had never announced them. (Note that this is no guarantee that the transaction is invalid, it may still be valid and available from another peer).


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Remote.Send.RequestTxIds


> Request a non-empty list of transaction identifiers from the client, and confirm a number of outstanding transaction identifiers. 
>  With 'TokBlocking' this is a a blocking operation: the response will always have at least one transaction identifier, and it does not expect a prompt response: there is no timeout. This covers the case when there is nothing else to do but wait. For example this covers leaf nodes that rarely, if ever, create and submit a transaction. 
>  With 'TokNonBlocking' this is a non-blocking operation: the response may be an empty list and this does expect a prompt response. This covers high throughput use cases where we wish to pipeline, by interleaving requests for additional transaction identifiers with requests for transactions, which requires these requests not block. 
>  The request gives the maximum number of transaction identifiers that can be accepted in the response. This must be greater than zero in the 'TokBlocking' case. In the 'TokNonBlocking' case either the numbers acknowledged or the number requested must be non-zero. In either case, the number requested must not put the total outstanding over the fixed protocol limit. 
> The request also gives the number of outstanding transaction identifiers that can now be acknowledged. The actual transactions to acknowledge are known to the peer based on the FIFO order in which they were provided. 
>  There is no choice about when to use the blocking case versus the non-blocking case, it depends on whether there are any remaining unacknowledged transactions (after taking into account the ones acknowledged in this message): 
>  * The blocking case must be used when there are zero remaining   unacknowledged transactions. 
>  * The non-blocking case must be used when there are non-zero remaining   unacknowledged transactions.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.Remote.Send.RequestTxs


> Request one or more transactions corresponding to the given  transaction identifiers.  
>  While it is the responsibility of the replying peer to keep within pipelining in-flight limits, the sender must also cooperate by keeping the total requested across all in-flight requests within the limits. 
> It is an error to ask for transaction identifiers that were not previously announced (via 'MsgReplyTxIds'). 
> It is an error to ask for transaction identifiers that are not outstanding or that were already asked for.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.TxInbound.CanRequestMoreTxs


> There are no replies in flight, but we do know some more txs we can ask for, so lets ask for them and more txids.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.TxInbound.CannotRequestMoreTxs


> There's no replies in flight, and we have no more txs we can ask for so the only remaining thing to do is to ask for more txids. Since this is the only thing to do now, we make this a blocking call.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.TxInbound.Collected


> Number of transactions just about to be inserted.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.TxInbound.Processed


> Just processed transaction pass/fail breakdown.


Severity:  `Debug`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.TxInbound.Terminated


> Server received 'MsgDone'.


Severity:  `Notice`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Visible` by config value: `Notice`

### TxSubmission.TxOutbound.ControlMessage




Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.TxOutbound.RecvMsgRequest


> The IDs of the transactions requested.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### TxSubmission.TxOutbound.SendMsgReply


> The transactions to be sent in the response.


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`

### Version.NodeVersion


> Node version information


Severity:  `Info`
Privacy:   `Public`
Details:   `DNormal`


From current configuration:

Backends:
      `EKGBackend`,
      `Stdout MachineFormat`,
      `Forwarder`
Filtered `Invisible` by config value: `Notice`
## Metrics

### Forge.DelegMapSize



Dispatched by: 
Forge.Loop.StartLeadershipCheckPlus

### Forge.UtxoSize



Dispatched by: 
Forge.Loop.StartLeadershipCheckPlus

### Mem.resident

> Kernel-reported RSS (resident set size)


Dispatched by: 
Resources

### RTS.alloc

> RTS-reported bytes allocated


Dispatched by: 
Resources

### RTS.gcHeapBytes

> RTS-reported heap bytes


Dispatched by: 
Resources

### RTS.gcLiveBytes

> RTS-reported live bytes


Dispatched by: 
Resources

### RTS.gcMajorNum

> Major GCs


Dispatched by: 
Resources

### RTS.gcMinorNum

> Minor GCs


Dispatched by: 
Resources

### RTS.gcticks

> RTS-reported CPU ticks spent on GC


Dispatched by: 
Resources

### RTS.mutticks

> RTS-reported CPU ticks spent on mutator


Dispatched by: 
Resources

### RTS.threads

> RTS green thread count


Dispatched by: 
Resources

### Stat.cputicks

> Kernel-reported CPU ticks (1/100th of a second), since process start


Dispatched by: 
Resources

### Stat.fsRd

> FS bytes read


Dispatched by: 
Resources

### Stat.fsWr

> FS bytes written


Dispatched by: 
Resources

### Stat.netRd

> IP packet bytes read


Dispatched by: 
Resources

### Stat.netWr

> IP packet bytes written


Dispatched by: 
Resources

### SuppressedMessages...

> Number of suppressed messages of a certain kind


Dispatched by: 
Reflection.StartLimiting

### aboutToLeadSlotLast



Dispatched by: 
Forge.Loop.StartLeadershipCheck

### adoptedOwnBlockSlotLast



Dispatched by: 
Forge.Loop.AdoptedBlock

### adoptionThreadDied



Dispatched by: 
Forge.Loop.AdoptionThreadDied

### blockContext



Dispatched by: 
Forge.Loop.BlockContext

### blockFromFuture



Dispatched by: 
Forge.Loop.BlockFromFuture

### blockNum

> Number of blocks in this chain fragment.


Dispatched by: 
ChainDB.AddBlockEvent.AddedToCurrentChain
ChainDB.AddBlockEvent.SwitchedToAFork

### blockReplayProgress

> Progress in percent


Dispatched by: 
ChainDB.ReplayBlock.LedgerReplay

### blockfetchclient.blockdelay



Dispatched by: 
BlockFetch.Client.ClientMetrics

### blockfetchclient.blockdelay.cdfFive



Dispatched by: 
BlockFetch.Client.ClientMetrics

### blockfetchclient.blockdelay.cdfOne



Dispatched by: 
BlockFetch.Client.ClientMetrics

### blockfetchclient.blockdelay.cdfThree



Dispatched by: 
BlockFetch.Client.ClientMetrics

### blockfetchclient.blocksize



Dispatched by: 
BlockFetch.Client.ClientMetrics

### blockfetchclient.lateblocks



Dispatched by: 
BlockFetch.Client.ClientMetrics

### blocksForged

> How many blocks did this node forge?


Dispatched by: 
Forge.ThreadStats.ForgeThreadStats

### cardano_build_info

> Cardano node build info


Dispatched by: 
Version.NodeVersion

### cardano_version_major

> Cardano node version information


Dispatched by: 
Version.NodeVersion

### cardano_version_minor

> Cardano node version information


Dispatched by: 
Version.NodeVersion

### cardano_version_patch

> Cardano node version information


Dispatched by: 
Version.NodeVersion

### connectedPeers

> Number of connected peers


Dispatched by: 
BlockFetch.Decision.Accept
BlockFetch.Decision.Decline

### connectionManager.duplexConns



Dispatched by: 
Net.ConnectionManager.Remote.ConnectionManagerCounters

### connectionManager.duplexConns



Dispatched by: 
Net.ConnectionManager.Local.ConnectionManagerCounters

### connectionManager.fullDuplexConns



Dispatched by: 
Net.ConnectionManager.Remote.ConnectionManagerCounters

### connectionManager.fullDuplexConns



Dispatched by: 
Net.ConnectionManager.Local.ConnectionManagerCounters

### connectionManager.inboundConns



Dispatched by: 
Net.ConnectionManager.Remote.ConnectionManagerCounters

### connectionManager.inboundConns



Dispatched by: 
Net.ConnectionManager.Local.ConnectionManagerCounters

### connectionManager.outboundConns



Dispatched by: 
Net.ConnectionManager.Remote.ConnectionManagerCounters

### connectionManager.outboundConns



Dispatched by: 
Net.ConnectionManager.Local.ConnectionManagerCounters

### connectionManager.unidirectionalConns



Dispatched by: 
Net.ConnectionManager.Remote.ConnectionManagerCounters

### connectionManager.unidirectionalConns



Dispatched by: 
Net.ConnectionManager.Local.ConnectionManagerCounters

### couldNotForgeSlotLast



Dispatched by: 
Forge.Loop.NoLedgerState
Forge.Loop.NoLedgerView

### currentKESPeriod



Dispatched by: 
Forge.StateInfo

### currentKESPeriod



Dispatched by: 
Forge.Loop.ForgeStateUpdateError

### density

> The actual number of blocks created over the maximum expected number of blocks that could be created over the span of the last @k@ blocks.


Dispatched by: 
ChainDB.AddBlockEvent.AddedToCurrentChain
ChainDB.AddBlockEvent.SwitchedToAFork

### epoch

> In which epoch is the tip of the current chain.


Dispatched by: 
ChainDB.AddBlockEvent.AddedToCurrentChain
ChainDB.AddBlockEvent.SwitchedToAFork

### forgedInvalidSlotLast



Dispatched by: 
Forge.Loop.ForgedInvalidBlock

### forgedSlotLast



Dispatched by: 
Forge.Loop.ForgedBlock

### forging_enabled

> Can this node forge blocks? (Is it provided with block forging credentials) 0 = no, 1 = yes


Dispatched by: 
Startup.BlockForgingUpdate

### haskell_compiler_major

> Cardano compiler version information


Dispatched by: 
Version.NodeVersion

### haskell_compiler_minor

> Cardano compiler version information


Dispatched by: 
Version.NodeVersion

### headersServed

> A counter triggered on any header event


Dispatched by: 
ChainSync.ServerHeader.Update

### headersServed

> A counter triggered on any header event


Dispatched by: 
ChainSync.ServerBlock.Update

### headersServed.falling

> A counter triggered only on header event with falling edge


Dispatched by: 
ChainSync.ServerHeader.Update

### headersServed.falling

> A counter triggered only on header event with falling edge


Dispatched by: 
ChainSync.ServerBlock.Update

### inboundGovernor.Cold



Dispatched by: 
Net.InboundGovernor.Remote.InboundGovernorCounters

### inboundGovernor.Cold



Dispatched by: 
Net.InboundGovernor.Local.InboundGovernorCounters

### inboundGovernor.Hot



Dispatched by: 
Net.InboundGovernor.Remote.InboundGovernorCounters

### inboundGovernor.Hot



Dispatched by: 
Net.InboundGovernor.Local.InboundGovernorCounters

### inboundGovernor.Idle



Dispatched by: 
Net.InboundGovernor.Remote.InboundGovernorCounters

### inboundGovernor.Idle



Dispatched by: 
Net.InboundGovernor.Local.InboundGovernorCounters

### inboundGovernor.Warm



Dispatched by: 
Net.InboundGovernor.Remote.InboundGovernorCounters

### inboundGovernor.Warm



Dispatched by: 
Net.InboundGovernor.Local.InboundGovernorCounters

### ledgerState



Dispatched by: 
Forge.Loop.LedgerState

### ledgerView



Dispatched by: 
Forge.Loop.LedgerView

### localInboundGovernor.cold



Dispatched by: 
Net.InboundGovernor.Remote.InboundGovernorCounters

### localInboundGovernor.cold



Dispatched by: 
Net.InboundGovernor.Local.InboundGovernorCounters

### localInboundGovernor.hot



Dispatched by: 
Net.InboundGovernor.Remote.InboundGovernorCounters

### localInboundGovernor.hot



Dispatched by: 
Net.InboundGovernor.Local.InboundGovernorCounters

### localInboundGovernor.idle



Dispatched by: 
Net.InboundGovernor.Remote.InboundGovernorCounters

### localInboundGovernor.idle



Dispatched by: 
Net.InboundGovernor.Local.InboundGovernorCounters

### localInboundGovernor.warm



Dispatched by: 
Net.InboundGovernor.Remote.InboundGovernorCounters

### localInboundGovernor.warm



Dispatched by: 
Net.InboundGovernor.Local.InboundGovernorCounters

### mempoolBytes

> Byte size of the mempool


Dispatched by: 
Mempool.AddedTx
Mempool.ManuallyRemovedTxs
Mempool.RejectedTx
Mempool.RemoveTxs

### nodeCannotForge



Dispatched by: 
Forge.Loop.NodeCannotForge

### nodeCannotForge

> How many times was this node unable to forge [a block]?


Dispatched by: 
Forge.ThreadStats.ForgeThreadStats

### nodeIsLeader



Dispatched by: 
Forge.Loop.NodeIsLeader

### nodeIsLeader

> How many times was this node slot leader?


Dispatched by: 
Forge.ThreadStats.ForgeThreadStats

### nodeNotLeader



Dispatched by: 
Forge.Loop.NodeNotLeader

### notAdoptedSlotLast



Dispatched by: 
Forge.Loop.DidntAdoptBlock

### operationalCertificateExpiryKESPeriod



Dispatched by: 
Forge.StateInfo

### operationalCertificateExpiryKESPeriod



Dispatched by: 
Forge.Loop.ForgeStateUpdateError

### operationalCertificateStartKESPeriod



Dispatched by: 
Forge.StateInfo

### operationalCertificateStartKESPeriod



Dispatched by: 
Forge.Loop.ForgeStateUpdateError

### peerSelection.ActiveBigLedgerPeers

> Number of active big ledger peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ActiveBigLedgerPeersDemotions

> Number of active big ledger peers demotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ActiveBootstrapPeers

> Number of active bootstrap peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ActiveBootstrapPeersDemotions

> Number of active bootstrap peers demotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ActiveLocalRootPeers

> Number of active local root peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ActiveLocalRootPeersDemotions

> Number of active local root peers demotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ActiveNonRootPeers

> Number of active non root peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ActiveNonRootPeersDemotions

> Number of active non root peers demotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ActivePeers

> Number of active peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ActivePeersDemotions

> Number of active peers demotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.Cold

> Number of cold peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ColdBigLedgerPeers

> Number of cold big ledger peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ColdBigLedgerPeersPromotions

> Number of cold big ledger peers promotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ColdBootstrapPeersPromotions

> Number of cold bootstrap peers promotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ColdNonRootPeersPromotions

> Number of cold non root peers promotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.ColdPeersPromotions

> Number of cold peers promotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.EstablishedBigLedgerPeers

> Number of established big ledger peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.EstablishedBootstrapPeers

> Number of established bootstrap peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.EstablishedLocalRootPeers

> Number of established local root peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.EstablishedNonRootPeers

> Number of established non root peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.EstablishedPeers

> Number of established peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.Hot

> Number of hot peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.HotBigLedgerPeers

> Number of hot big ledger peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.KnownBigLedgerPeers

> Number of known big ledger peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.KnownBootstrapPeers

> Number of known bootstrap peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.KnownLocalRootPeers

> Number of known local root peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.KnownNonRootPeers

> Number of known non root peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.KnownPeers

> Number of known peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.LocalRoots

> Numbers of warm & hot local roots


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.RootPeers

> Number of root peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.Warm

> Number of warm peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.WarmBigLedgerPeers

> Number of warm big ledger peers


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.WarmBigLedgerPeersDemotions

> Number of warm big ledger peers demotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.WarmBigLedgerPeersPromotions

> Number of warm big ledger peers promotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.WarmBootstrapPeersDemotions

> Number of warm bootstrap peers demotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.WarmBootstrapPeersPromotions

> Number of warm bootstrap peers promotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.WarmLocalRootPeersPromotions

> Number of warm local root peers promotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.WarmNonRootPeersDemotions

> Number of warm non root peers demotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.WarmNonRootPeersPromotions

> Number of warm non root peers promotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.WarmPeersDemotions

> Number of warm peers demotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.WarmPeersPromotions

> Number of warm peers promotions


Dispatched by: 
Net.PeerSelection.Counters.Counters

### peerSelection.churn.DecreasedActiveBigLedgerPeers

> number of decreased active big ledger peers


Dispatched by: 
Net.Churn.ChurnCounters

### peerSelection.churn.DecreasedActivePeers

> number of decreased active peers


Dispatched by: 
Net.Churn.ChurnCounters

### peerSelection.churn.DecreasedEstablishedBigLedgerPeers

> number of decreased established big ledger peers


Dispatched by: 
Net.Churn.ChurnCounters

### peerSelection.churn.DecreasedEstablishedPeers

> number of decreased established peers


Dispatched by: 
Net.Churn.ChurnCounters

### peerSelection.churn.DecreasedKnownBigLedgerPeers

> number of decreased known big ledger peers


Dispatched by: 
Net.Churn.ChurnCounters

### peerSelection.churn.DecreasedKnownPeers

> number of decreased known peers


Dispatched by: 
Net.Churn.ChurnCounters

### peerSelection.churn.IncreasedActiveBigLedgerPeers

> number of increased active big ledger peers


Dispatched by: 
Net.Churn.ChurnCounters

### peerSelection.churn.IncreasedActivePeers

> number of increased active peers


Dispatched by: 
Net.Churn.ChurnCounters

### peerSelection.churn.IncreasedEstablishedBigLedgerPeers

> number of increased established big ledger peers


Dispatched by: 
Net.Churn.ChurnCounters

### peerSelection.churn.IncreasedEstablishedPeers

> number of increased established peers


Dispatched by: 
Net.Churn.ChurnCounters

### peerSelection.churn.IncreasedKnownBigLedgerPeers

> number of increased known big ledger peers


Dispatched by: 
Net.Churn.ChurnCounters

### peerSelection.churn.IncreasedKnownPeers

> number of increased known peers


Dispatched by: 
Net.Churn.ChurnCounters

### peersFromNodeKernel



Dispatched by: 
Net.Peers.List.PeersFromNodeKernel

### remainingKESPeriods



Dispatched by: 
Forge.StateInfo

### remainingKESPeriods



Dispatched by: 
Forge.Loop.ForgeStateUpdateError

### served.block



Dispatched by: 
BlockFetch.Server.SendBlock

### slotInEpoch

> Relative slot number of the tip of the current chain within the epoch..


Dispatched by: 
ChainDB.AddBlockEvent.AddedToCurrentChain
ChainDB.AddBlockEvent.SwitchedToAFork

### slotIsImmutable



Dispatched by: 
Forge.Loop.SlotIsImmutable

### slotNum

> Number of slots in this chain fragment.


Dispatched by: 
ChainDB.AddBlockEvent.AddedToCurrentChain
ChainDB.AddBlockEvent.SwitchedToAFork

### slotsMissed

> How many slots did this node miss?


Dispatched by: 
Forge.ThreadStats.ForgeThreadStats

### submissions.accepted



Dispatched by: 
TxSubmission.TxInbound.Processed

### submissions.rejected



Dispatched by: 
TxSubmission.TxInbound.Processed

### submissions.submitted



Dispatched by: 
TxSubmission.TxInbound.Collected

### systemStartTime

> The UTC time this node was started.


Dispatched by: 
Startup.Common

### txsInMempool

> Transactions in mempool


Dispatched by: 
Mempool.AddedTx
Mempool.ManuallyRemovedTxs
Mempool.RejectedTx
Mempool.RemoveTxs

### txsProcessedNum



Dispatched by: 
Mempool.ManuallyRemovedTxs
## Datapoints

### NodeInfo


> Basic information about this node collected at startup
>
>  _niName_: Name of the node. 
>  _niProtocol_: Protocol which this nodes uses. 
>  _niVersion_: Software version which this node is using. 
>  _niStartTime_: Start time of this node. 
>  _niSystemStartTime_: How long did the start of the node took.


### NodeStartupInfo


> Startup information about this node, required for RTView
>
>  _suiEra_: Name of the current era. 
>  _suiSlotLength_: Slot length, in seconds. 
>  _suiEpochLength_: Epoch length, in slots. 
>  _suiSlotsPerKESPeriod_: KES period length, in slots.

## Configuration: 
```
{
    "TraceOptionForwarder": null,
    "TraceOptionMetricsPrefix": null,
    "TraceOptionNodeName": null,
    "TraceOptionPeerFrequency": 3000,
    "TraceOptionResourceFrequency": 4000,
    "TraceOptions": {
        "": {
            "backends": [
                "Stdout MachineFormat",
                "EKGBackend",
                "Forwarder"
            ],
            "detail": "DNormal",
            "severity": "Notice"
        },
        "BlockFetch.Client.CompletedBlockFetch": {
            "maxFrequency": 2
        },
        "BlockFetch.Decision": {
            "severity": "Info"
        },
        "ChainDB": {
            "severity": "Info"
        },
        "ChainDB.AddBlockEvent.AddBlockValidation.ValidCandidate": {
            "maxFrequency": 2
        },
        "ChainDB.AddBlockEvent.AddedBlockToQueue": {
            "maxFrequency": 2
        },
        "ChainDB.AddBlockEvent.AddedBlockToVolatileDB": {
            "maxFrequency": 2
        },
        "ChainDB.CopyToImmutableDBEvent.CopiedBlockToImmutableDB": {
            "maxFrequency": 2
        },
        "ChainSync.Client": {
            "severity": "Info"
        },
        "ChainSync.Client.DownloadedHeader": {
            "maxFrequency": 2
        },
        "Forge.Loop": {
            "severity": "Info"
        },
        "Forge.StateInfo": {
            "severity": "Info"
        },
        "Mempool": {
            "severity": "Info"
        },
        "Net.ConnectionManager.Remote": {
            "severity": "Info"
        },
        "Net.ErrorPolicy": {
            "severity": "Info"
        },
        "Net.ErrorPolicy.Local": {
            "severity": "Info"
        },
        "Net.InboundGovernor.Remote": {
            "severity": "Info"
        },
        "Net.Mux.Remote": {
            "severity": "Info"
        },
        "Net.PeerSelection": {
            "severity": "Info"
        },
        "Net.Subscription.DNS": {
            "severity": "Info"
        },
        "Net.Subscription.IP": {
            "severity": "Info"
        },
        "Resources": {
            "severity": "Info"
        },
        "Startup.DiffusionInit": {
            "severity": "Info"
        }
    }
}
```
653 log messages, 
156 metrics,
2 datapoints.

ⓣ- This is the root of a tracer

ⓢ- This is the root of a tracer that is silent because of the current configuration

ⓜ- This is the root of a tracer, that provides metrics

Generated at 2024-09-04 11:24:43.975290647 CEST.
