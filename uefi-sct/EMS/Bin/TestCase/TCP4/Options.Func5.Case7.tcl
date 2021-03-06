# 
#  Copyright 2006 - 2010 Unified EFI, Inc.<BR> 
#  Copyright (c) 2010, Intel Corporation. All rights reserved.<BR>
# 
#  This program and the accompanying materials
#  are licensed and made available under the terms and conditions of the BSD License
#  which accompanies this distribution.  The full text of the license may be found at 
#  http://opensource.org/licenses/bsd-license.php
# 
#  THE PROGRAM IS DISTRIBUTED UNDER THE BSD LICENSE ON AN "AS IS" BASIS,
#  WITHOUT WARRANTIES OR REPRESENTATIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED.
# 
################################################################################
CaseLevel         FUNCTION
CaseAttribute     AUTO
CaseVerboseLevel  DEFAULT

#
# test case Name, category, description, GUID...
#
CaseGuid          4426EBCC-B5A6-47e6-AB6A-BFCC7DAC01F3
CaseName          Options.Func5.Case7
CaseCategory      TCP
CaseDescription   {This case is to test the Functionality.                     \
                   -- This item is to test the [EUT] correctly handles the     \
                   reception of segments with unaligned window scale option.   \
                   -- format 3:                                                \
                     0            7           15           23           31     \
                     +------------+------------+------------+------------+     \
                     |   No-Oper  |   No-Oper  |   No-Oper  |  00000011  |     \
                     +------------+------------+------------+------------+     \
                     +------------+------------+------------+------------+     \
                     |  00000011  |  shift.cnt |   No-Oper  |   No-Oper  |     \
                     +------------+------------+------------+------------+}
################################################################################

Include TCP4/include/Tcp4.inc.tcl

proc CleanUpEutEnvironmentBegin {} {
  global RST
  UpdateTcpSendBuffer TCB -c $RST
  SendTcpPacket TCB

  DestroyTcb
  DestroyPacket
  DelEntryInArpCache

  Tcp4ServiceBinding->DestroyChild "@R_Handle, &@R_Status"
  GetAck

  Tcp4ServiceBinding->DestroyChild "@R_Accept_NewChildHandle, &@R_Status"
  GetAck

}

proc CleanUpEutEnvironmentEnd {} {
  EndLogPacket
  EndScope _TCP4_SPEC_CONFORMANCE_
  EndLog
}

#
# Begin log ...
#
BeginLog

#
# BeginScope
#
BeginScope _TCP4_SPEC_CONFORMANCE_

BeginLogPacket Options.Func7.Case7 "host $DEF_EUT_IP_ADDR and host             \
                                             $DEF_ENTS_IP_ADDR"

#
# Parameter Definition
# R_ represents "Remote EFI Side Parameter"
# L_ represents "Local OS Side Parameter"
#
set    L_FragmentLength          1460    ;# data to transmit by [EUT]
set    L_MSS                     800     ;# MSS claimed by [OS]
set    L_WindowField             64      ;# [OS] TCP header - Window Field
set    L_WindowScale             2       ;# [OS] TCP option - Window Scale
#
# Calculate [OS] MAX acceptable window
#
set    L_RCV_WND                 [ expr $L_WindowField << $L_WindowScale ]

UINTN                            R_Status
UINTN                            R_Handle
UINTN                            R_Context

EFI_TCP4_CONFIG_DATA             R_Tcp4ConfigData
EFI_IP4_MODE_DATA                R_Ip4ModeData
EFI_MANAGED_NETWORK_CONFIG_DATA  R_MnpConfigData
EFI_SIMPLE_NETWORK_MODE          R_SnpModeData

EFI_TCP4_ACCESS_POINT            R_Configure_AccessPoint
EFI_TCP4_CONFIG_DATA             R_Configure_Tcp4ConfigData
EFI_TCP4_OPTION                  R_Configure_ControlOption

EFI_TCP4_LISTEN_TOKEN            R_Accept_ListenToken
UINTN                            R_Accept_NewChildHandle
EFI_TCP4_COMPLETION_TOKEN        R_Accept_CompletionToken

EFI_TCP4_IO_TOKEN                R_Transmit_IOToken
EFI_TCP4_COMPLETION_TOKEN        R_Transmit_CompletionToken

Packet                           R_Packet_Buffer
EFI_TCP4_TRANSMIT_DATA           R_TxData
EFI_TCP4_FRAGMENT_DATA           R_FragmentTable
UINT8                            R_FragmentBuffer($L_FragmentLength)

#
# Build TCP Segment with MSS OPTION, MSS = $L_MSS.
# Notes: Windows will ignore MSS less than 88 bytes, and use default MSS = 88,
#        however in RFC 793, 1122, 879 haven't specify the minimum value of MSS.
#        And EFI conform to RFC.
#
set L_MSSH  [ expr $L_MSS / 0x0100 ]    ;# Get High byte, div 256
set L_MSSL  [ expr $L_MSS % 0x0100 ]    ;# Get Low byte, mod 256

set L_MSSH  0x[ format %02x $L_MSSH ]    ;# Change L_MSSH to HEX format
set L_MSSL  0x[ format %02x $L_MSSL ]    ;# Change L_MSSL to HEX format

#
# Create TCP option.
# MSS = L_MSS,
# Windows Scale: shift.cnt = 2
#
CreatePayload Option_MSS_WS Data 12 0x02 0x04 $L_MSSH $L_MSSL 0x01 0x01 0x01 0x03\
              0x03 $L_WindowScale 0x01 0x01

#
# Initialization of TCB related on OS side.
#
CreateTcb TCB $DEF_ENTS_IP_ADDR $DEF_ENTS_PRT $DEF_EUT_IP_ADDR $DEF_EUT_PRT

LocalEther  $DEF_ENTS_MAC_ADDR
RemoteEther $DEF_EUT_MAC_ADDR
LocalIp     $DEF_ENTS_IP_ADDR
RemoteIp    $DEF_EUT_IP_ADDR

#
# Add an entry in ARP cache.
#
AddEntryInArpCache

#
# Create Tcp4 Child.
#
Tcp4ServiceBinding->CreateChild "&@R_Handle, &@R_Status"
GetAck
SetVar     [subst $ENTS_CUR_CHILD]  @R_Handle
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "Tcp4SBP.CreateChild - Create Child 1"                         \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

#
# Configure TCP instance.
#
SetVar          R_Configure_AccessPoint.UseDefaultAddress  FALSE
SetIpv4Address  R_Configure_AccessPoint.StationAddress     $DEF_EUT_IP_ADDR
SetIpv4Address  R_Configure_AccessPoint.SubnetMask         $DEF_EUT_MASK
SetVar          R_Configure_AccessPoint.StationPort        $DEF_EUT_PRT
SetIpv4Address  R_Configure_AccessPoint.RemoteAddress      $DEF_ENTS_IP_ADDR
SetVar          R_Configure_AccessPoint.RemotePort         $DEF_ENTS_PRT
SetVar          R_Configure_AccessPoint.ActiveFlag         FALSE

SetVar R_Configure_Tcp4ConfigData.TypeOfService       1
SetVar R_Configure_Tcp4ConfigData.TimeToLive          128
SetVar R_Configure_Tcp4ConfigData.AccessPoint         @R_Configure_AccessPoint

SetVar R_Configure_ControlOption.EnableWindowScaling  TRUE

Tcp4->Configure {&@R_Configure_Tcp4ConfigData, &@R_Status}
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "Tcp4.Configure - Configure Child 1."                          \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

set L_TcpFlag [expr $SYN]
UpdateTcpSendBuffer TCB -c $L_TcpFlag -w $L_WindowField -o Option_MSS_WS
SendTcpPacket TCB

#
# Call Tcp4.Accept() to accept a connetion.
#
BS->CreateEvent "$EVT_NOTIFY_SIGNAL, $EFI_TPL_CALLBACK, 1, &@R_Context,        \
                 &@R_Accept_CompletionToken.Event, &@R_Status"
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "BS.CreateEvent."                                              \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

SetVar R_Accept_ListenToken.CompletionToken @R_Accept_CompletionToken
SetVar R_Accept_ListenToken.CompletionToken.Status $EFI_INCOMPATIBLE_VERSION

Tcp4->Accept {&@R_Accept_ListenToken, &@R_Status}
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "Tcp4.Accept - Accept a connection."                           \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

#
# OS get SYN & ACK segment
#
ReceiveTcpPacket TCB 5

if { ${TCB.received} == 1 } {
  if { ${TCB.r_f_syn} != 1 && ${TCB.r_f_ack} != 1 } {
    set assert fail
    puts "EUT doesn't send out SYN & ACK segment correctly."
    RecordAssertion $assert $GenericAssertionGuid                              \
                    "EUT doesn't send out SYN & ACK segment correctly."

    CleanUpEutEnvironmentBegin
    BS->CloseEvent "@R_Accept_CompletionToken.Event, &@R_Status"
    GetAck
    CleanUpEutEnvironmentEnd
    return
  }
} else {
  set assert fail
  puts "EUT doesn't send out any segment."
  RecordAssertion $assert $GenericAssertionGuid                                \
                  "EUT doesn't send out any segment."

  CleanUpEutEnvironmentBegin
  BS->CloseEvent "@R_Accept_CompletionToken.Event, &@R_Status"
  GetAck
  CleanUpEutEnvironmentEnd
  return
}

#
# OS send ACK segment
#
UpdateTcpSendBuffer TCB -c $ACK -w $L_WindowField
SendTcpPacket TCB

#
# Get the NewChildHandle value.
#
GetVar R_Accept_ListenToken.NewChildHandle
SetVar R_Accept_NewChildHandle ${R_Accept_ListenToken.NewChildHandle}
SetVar [subst $ENTS_CUR_CHILD]  @R_Accept_NewChildHandle

#
# Call Tcp4.Transmit() to transmit a packet.
#
BS->CreateEvent "$EVT_NOTIFY_SIGNAL, $EFI_TPL_CALLBACK, 1, &@R_Context,        \
                 &@R_Transmit_CompletionToken.Event, &@R_Status"
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "BS.CreateEvent."                                              \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

SetVar R_TxData.Push                      FALSE
SetVar R_TxData.Urgent                    FALSE
SetVar R_TxData.DataLength                $L_FragmentLength
SetVar R_TxData.FragmentCount             1

SetVar R_FragmentTable.FragmentLength     $L_FragmentLength
SetVar R_FragmentTable.FragmentBuffer     &@R_FragmentBuffer
SetVar R_TxData.FragmentTable(0)          @R_FragmentTable

SetVar R_Packet_Buffer.TxData  &@R_TxData

SetVar R_Transmit_IOToken.CompletionToken         @R_Transmit_CompletionToken
SetVar R_Transmit_IOToken.Packet_Buffer           @R_Packet_Buffer
SetVar R_Transmit_IOToken.CompletionToken.Status  $EFI_INCOMPATIBLE_VERSION

Tcp4->Transmit {&@R_Transmit_IOToken, &@R_Status}
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                                  \
                "Tcp4.Transmit - Transmit a packet."                           \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

#
# Do loop that [OS] need to capture the TCP Segment fragement.
#
set sum_fragment 0      ;# initial total received fragment size to zero.
set index        0      ;# initial fragment index to zero.
while { $sum_fragment < $L_FragmentLength } {
  incr index
  #
  # [OS] get the transmitted data segment.
  #
  ReceiveTcpPacket TCB 5

  if { ${TCB.received} == 1 } {
    if { ${TCB.r_f_ack} != 1 } {
      RecordAssertion fail $GenericAssertionGuid                               \
                      "EUT wrongly send out segment, fragment $index."

      CleanUpEutEnvironmentBegin
      BS->CloseEvent "@R_Accept_CompletionToken.Event, &@R_Status"
      GetAck
      BS->CloseEvent "@R_Transmit_CompletionToken.Event, &@R_Status"
      GetAck
      CleanUpEutEnvironmentEnd
      return
    } elseif { ${TCB.r_seq} != [ expr $sum_fragment + 1 ] } {    ;# check r_seq
        puts "{TCB.r_seq} = ${TCB.r_seq}"
        puts "Expected Sequence Number = [ expr $sum_fragment + 1 ]"
        RecordAssertion fail $GenericAssertionGuid                             \
                        "EUT send TCP data segment sequence unequal to OS expect."

        CleanUpEutEnvironmentBegin
        BS->CloseEvent "@R_Accept_CompletionToken.Event, &@R_Status"
        GetAck
        BS->CloseEvent "@R_Transmit_CompletionToken.Event, &@R_Status"
        GetAck
        CleanUpEutEnvironmentEnd
        return
    } elseif { ${TCB.r_len} > $L_RCV_WND } {          ;# check r_len > RCV_WND?
        puts "{TCB.r_len} = ${TCB.r_len}"
        puts "Expected Segment Data Size should no more than $L_RCV_WND."
        RecordAssertion fail $GenericAssertionGuid                             \
                        "EUT send TCP Segment Data Size larger than OS receive window."

        CleanUpEutEnvironmentBegin
        BS->CloseEvent "@R_Accept_CompletionToken.Event, &@R_Status"
        GetAck
        BS->CloseEvent "@R_Transmit_CompletionToken.Event, &@R_Status"
        GetAck
        CleanUpEutEnvironmentEnd
        return
    } elseif { ${TCB.r_len} > $L_MSS } {              ;# check r_len > MSS?
        puts "{TCB.r_len} = ${TCB.r_len}"
        puts "Expected Segment Data Size should no more than $L_MSS."
        RecordAssertion fail $GenericAssertionGuid                             \
                        "EUT send TCP Segment Data Size larger than OS MSS."

        CleanUpEutEnvironmentBegin
        BS->CloseEvent "@R_Accept_CompletionToken.Event, &@R_Status"
        GetAck
        BS->CloseEvent "@R_Transmit_CompletionToken.Event, &@R_Status"
        GetAck
        CleanUpEutEnvironmentEnd
        return
    } else {
        # correct;
        RecordAssertion pass $GenericAssertionGuid                             \
                        "EUT correctly divide up TCP data segment to send. fragment $index."
        set sum_fragment [ expr $sum_fragment + ${TCB.r_len}]
    }
  } else {
      set assert fail
      RecordAssertion $assert $GenericAssertionGuid                            \
                      "EUT doesn't send out TCP segment, fragment $index."

      CleanUpEutEnvironmentBegin
      BS->CloseEvent "@R_Accept_CompletionToken.Event, &@R_Status"
      GetAck
      BS->CloseEvent "@R_Transmit_CompletionToken.Event, &@R_Status"
      GetAck
      CleanUpEutEnvironmentEnd
      return
  }

  #
  # [OS] send ACK segment.
  #
  UpdateTcpSendBuffer TCB -c $ACK -w $L_WindowField
  SendTcpPacket TCB
}

#
# Check the Token.Status to verify the data has been transmitted successfully.
#
while {1 > 0} {
  Stall 1
  GetVar R_Transmit_IOToken.CompletionToken.Status

  if { ${R_Transmit_IOToken.CompletionToken.Status} != $EFI_INCOMPATIBLE_VERSION} {
    if { ${R_Transmit_IOToken.CompletionToken.Status} != $EFI_SUCCESS} {
      set assert fail
      RecordAssertion $assert $Tcp4OptionsFunc5AssertionGuid007                \
                      "Data transmission failed."                              \
                      "ReturnStatus - ${R_Transmit_IOToken.CompletionToken.Status},\
                       ExpectedStatus - $EFI_SUCCESS"

      CleanUpEutEnvironmentBegin
      BS->CloseEvent "@R_Accept_CompletionToken.Event, &@R_Status"
      GetAck
      BS->CloseEvent "@R_Transmit_CompletionToken.Event, &@R_Status"
      GetAck
      CleanUpEutEnvironmentEnd
      return
    } else {
      break
    }
  }
}

#
# Clean up the environment on EUT side.
#
CleanUpEutEnvironmentBegin
BS->CloseEvent "@R_Accept_CompletionToken.Event, &@R_Status"
GetAck
BS->CloseEvent "@R_Transmit_CompletionToken.Event, &@R_Status"
GetAck
CleanUpEutEnvironmentEnd
