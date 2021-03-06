%------------------------------------------------------------------------------
%                          UWB positioning system
% Programmed by Chenhao
% version 2.1
% Add compressive sensing (CS) framework
% - CS sampling: random demodulator
% - CS recovery: CoSaMP algorithm
% version 1.0 
% - 1 Tag and 3 Receivers
% - locationg algorithm: TOA 
% - PPM repetition pulse
% - Indoor channel ieee802.15.4a, LOS, CM1
%------------------------------------------------------------------------------

clear all;
close all;
clc;

%------------------------------------------------------------------------------
% Initialization
%------------------------------------------------------------------------------

% Speed of Light
light_speed = 3e8;

fs = 20e9; %sample rate-10 times the highest frequency in GHz
ts = 1/fs; %sample period
t = [(-1.5E-9-ts):ts:(1.5E-9-ts)]; %vector with sample instants
t1 = .5E-9; %pulse width(0.5 nanoseconds)

% Pulse repetition interval, PRI
pri = 200e-9;

% The SNR range (in dB)
EbNo = -15;
 
% Number of bits
num_bits = 10;

%------------------------------------------------------------------------------
% locations
%------------------------------------------------------------------------------

% Tag's initial coordinate
Tag = [1 1];

% Coordinates of APs
AP = [0 0; 0 10; 10 0]; % in meters

% Number of Access Points (AP)
num_ap = length(AP);

%------------------------------------------------------------------------------
% Gaussian pulse generation
%------------------------------------------------------------------------------

pulse_order = 1; % 0-Gaussian pulse, 1-First derivative of Gaussian pulse, 2 - Second derivative;
A = 1; %positive amplitude
[y] = monocycle(fs, ts, t, t1, A, pulse_order); ref = y;
n_pulse_pri = round(pri/ts);          % Sampling of PRI
sig = zeros(1,n_pulse_pri);    
sig(1:length(y)) = y;                 % One pulse in one PRI

%-----------------------------------------------------------------
% LOS distance estimation
%-----------------------------------------------------------------

% Distance calculation between each AP and the Tag, IDEAL case
for ii = 1:num_ap
    dist_ap_tag(ii) = dist_t(AP(ii,:), Tag);
    % Time from each AP to Tag
    time_ap_tag(ii) = dist_ap_tag(ii)/light_speed;
end

%------------------------------------------------------------------------------
% Indoor channel ieee802.15.4a
%------------------------------------------------------------------------------

load ieee802.15.4a.cm1.10chan.mat
hi = abs(h);

%------------------------------------------------------------------------------
% Transmission
%------------------------------------------------------------------------------
   
for j = 1:num_bits
    for i = 1:num_ap
        % delayed signals 
        del_sample_ap_tag = round(time_ap_tag(i)/ts);
        xx = zeros(1,del_sample_ap_tag);
        del_sig_ap_tag(j,:) = [xx sig(1:end-length(xx))]; %
        
        % traversal channels 
        h = hi(:,j);
        conv_data = conv(del_sig_ap_tag(j,:), h);
        ap_tag_chan(j,:,i) = conv_data(1:length(sig)); %
        end
end

%-------------------------------------------------------
% additive white gaussian noise (AWGN)  
%-------------------------------------------------------

noise_var   = 10^(-EbNo/10);
for j = 1:num_bits
    for i = 1:num_ap
        ap_tag_chan_wgn(j,:,i) = ap_tag_chan(j,:,i)/std(ap_tag_chan(j,:,i)) + randn(1,length(ap_tag_chan(j,:,i))) .* sqrt(noise_var);
    end
end

%-------------------------------------------------------
% Receive and Xccorlation 
%-------------------------------------------------------
    
for i = 1:num_ap
    
    %receive signal from all channels
    ap_tag_chan_wgn_tmp = ap_tag_chan_wgn(:,:,i);
    received_signl_ap = sum(ap_tag_chan_wgn_tmp)/num_bits;
    
    %compressed sensing framework
    [A,y] = randmodu(received_signl_ap',1500);
    z = cosamp(A,y,1,1e-5,20);
    
    %xccorlation
    xc = xcorr(ref, received_signl_ap); 
    [a,delay(i)]=max(xc);
    TOA(i) = (length(sig) - delay(i)) * ts;
    
    %compressive sensing xccorlation
    xcz = xcorr(ref, z);
    [a,cs_delay(i)]=max(xcz);
    CS_TOA(i) = (length(sig) - cs_delay(i)) * ts;
    
end

%-------------------------------------------------------
% TOA locationing  
%-------------------------------------------------------

time_ap_tag = time_ap_tag
time_dur = TOA
toa_error = toa(AP, Tag, time_dur, light_speed)
cs_time_dur = CS_TOA
cs_toa_error = toa(AP, Tag, cs_time_dur, light_speed)
