//
//  CompactHomeView.swift
//  boringNotch
//

import Defaults
import SwiftUI

struct CompactHomeView: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var routeManager = AudioRouteManager.shared
    let albumArtNamespace: Namespace.ID

    @State private var sliderValue: Double = 0
    @State private var dragging = false
    @State private var lastDragged: Date = .distantPast
    @State private var showingOutputPicker = false
    @State private var outputPickerInteractionHeld = false

    @Default(.playerColorTinting) private var playerColorTinting

    private let albumArtSize: CGFloat = 45
    private let controlSize: CGFloat = 32
    private let playPauseSize: CGFloat = 46

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: albumArtSize)

            progress
                .frame(height: 36)
                .padding(.top, 4)

            transport
                .padding(.top, 1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .buttonStyle(.plain)
        .onAppear {
            sliderValue = musicManager.elapsedTime
            routeManager.refreshDevices()
        }
        .onChange(of: showingOutputPicker) { _, isPresented in
            if !isPresented {
                releaseOutputPickerInteraction()
            }
        }
        .onDisappear {
            releaseOutputPickerInteraction()
        }
    }

    private var header: some View {
        GeometryReader { geometry in
            let textWidth = max(0, geometry.size.width - albumArtSize - 64)

            HStack(spacing: 10) {
                compactAlbumArt

                VStack(alignment: .leading, spacing: 1) {
                    MarqueeText(
                        $musicManager.songTitle,
                        font: .system(size: 12, weight: .semibold),
                        nsFont: .caption1,
                        textColor: .white,
                        frameWidth: textWidth
                    )
                    MarqueeText(
                        $musicManager.artistName,
                        font: .system(size: 10),
                        nsFont: .caption2,
                        textColor: playerColorTinting
                            ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6)
                            : .gray,
                        frameWidth: textWidth
                    )
                }
                .frame(width: textWidth, alignment: .leading)

                AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                    .frame(width: 18, height: 18)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var compactAlbumArt: some View {
        Button {
            musicManager.openMusicApp()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: albumArtSize, height: albumArtSize)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)

                if !musicManager.usingAppIconForArtwork {
                    AppIcon(for: musicManager.bundleIdentifier ?? "com.apple.Music")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .offset(x: 4, y: 4)
                }
            }
            .frame(width: albumArtSize, height: albumArtSize)
        }
        .buttonStyle(.plain)
    }

    private var progress: some View {
        TimelineView(.animation(minimumInterval: musicManager.playbackRate > 0 ? 0.1 : nil)) { timeline in
            MusicSliderView(
                sliderValue: $sliderValue,
                duration: $musicManager.songDuration,
                lastDragged: $lastDragged,
                color: musicManager.avgColor,
                dragging: $dragging,
                currentDate: timeline.date,
                timestampDate: musicManager.timestampDate,
                elapsedTime: musicManager.elapsedTime,
                playbackRate: musicManager.playbackRate,
                isPlaying: musicManager.isPlaying
            ) { value in
                MusicManager.shared.seek(to: value)
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 10) {
            compactButton(
                icon: "shuffle",
                size: controlSize,
                glyphSize: 15,
                tint: musicManager.isShuffled ? .red : .white
            ) {
                MusicManager.shared.toggleShuffle()
            }

            compactButton(icon: "backward.fill", size: controlSize, glyphSize: 15) {
                MusicManager.shared.previousTrack()
            }

            compactButton(
                icon: musicManager.isPlaying ? "pause.fill" : "play.fill",
                size: playPauseSize,
                glyphSize: 22
            ) {
                MusicManager.shared.togglePlay()
            }

            compactButton(icon: "forward.fill", size: controlSize, glyphSize: 15) {
                MusicManager.shared.nextTrack()
            }

            compactButton(icon: routeSymbol, size: controlSize, glyphSize: 15) {
                presentOutputPicker()
            }
            .popover(isPresented: $showingOutputPicker, arrowEdge: .bottom) {
                AudioOutputPicker(routeManager: routeManager) {
                    showingOutputPicker = false
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: playPauseSize)
    }

    private func compactButton(
        icon: String,
        size: CGFloat,
        glyphSize: CGFloat,
        tint: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        CompactControlButton(
            icon: icon,
            frameSize: size,
            glyphSize: glyphSize,
            tint: tint,
            action: action
        )
    }

    private var routeSymbol: String {
        routeManager.activeDevice?.iconName ?? "airplayaudio"
    }

    private func presentOutputPicker() {
        routeManager.refreshDevices()
        guard !showingOutputPicker else {
            showingOutputPicker = false
            return
        }
        if !outputPickerInteractionHeld {
            SharingStateManager.shared.beginInteraction()
            outputPickerInteractionHeld = true
        }
        showingOutputPicker = true
    }

    private func releaseOutputPickerInteraction() {
        guard outputPickerInteractionHeld else { return }
        SharingStateManager.shared.endInteraction()
        outputPickerInteractionHeld = false
    }
}

struct AudioOutputPicker: View {
    @ObservedObject var routeManager: AudioRouteManager
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Output")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            if routeManager.devices.isEmpty {
                Text("Looking for devices…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            } else {
                ForEach(routeManager.devices) { device in
                    Button {
                        routeManager.select(device)
                        onSelect()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: device.iconName)
                                .frame(width: 18)
                            Text(device.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer(minLength: 12)
                            if device.id == routeManager.activeDeviceID {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)
            }
        }
        .frame(minWidth: 220)
    }
}

private struct CompactControlButton: View {
    let icon: String
    let frameSize: CGFloat
    let glyphSize: CGFloat
    let tint: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: frameSize * 0.4, style: .continuous)
                .fill(isHovering ? Color.white.opacity(0.12) : .clear)
                .frame(width: frameSize, height: frameSize)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: glyphSize, weight: .medium))
                        .foregroundStyle(tint)
                        .contentTransition(.symbolEffect(.replace))
                }
                .contentShape(RoundedRectangle(cornerRadius: frameSize * 0.4, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
    }
}

struct MediaOutputSlotButton: View {
    @ObservedObject private var routeManager = AudioRouteManager.shared
    @State private var showingPicker = false
    @State private var interactionHeld = false

    var body: some View {
        HoverButton(icon: routeSymbol, scale: .medium) {
            presentPicker()
        }
        .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
            AudioOutputPicker(routeManager: routeManager) {
                showingPicker = false
            }
        }
        .onChange(of: showingPicker) { _, isPresented in
            if !isPresented {
                releaseInteraction()
            }
        }
        .onDisappear {
            releaseInteraction()
        }
    }

    private var routeSymbol: String {
        routeManager.activeDevice?.iconName ?? "airplayaudio"
    }

    private func presentPicker() {
        routeManager.refreshDevices()
        guard !showingPicker else {
            showingPicker = false
            return
        }
        if !interactionHeld {
            SharingStateManager.shared.beginInteraction()
            interactionHeld = true
        }
        showingPicker = true
    }

    private func releaseInteraction() {
        guard interactionHeld else { return }
        SharingStateManager.shared.endInteraction()
        interactionHeld = false
    }
}
