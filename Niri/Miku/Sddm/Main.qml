import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#050008"

    Image {
        anchors.fill: parent
        source: "wallpaper.png"
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        anchors.fill: parent
        color: "#050008"
        opacity: 0.45
    }

    Rectangle {
        id: loginBox
        width: 320
        height: loginColumn.implicitHeight + 48
        x: 840
        anchors.verticalCenter: parent.verticalCenter
        color: "#1E3E4AE6"
        border.color: "#4FBEF0"
        border.width: 2
        radius: 12
        layer.enabled: true
        layer.effect: DropShadow {
            color: "#000000"
            radius: 18
            samples: 32
            spread: 0.1
        }

        ColumnLayout {
            id: loginColumn
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 24 }
            spacing: 16

            // Avatar
            Item {
                Layout.alignment: Qt.AlignHCenter
                width: 90; height: 90
                Image {
                    anchors.fill: parent
                    source: "avatar.png"
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle { width: 90; height: 90; radius: 45; visible: false }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 45; color: "transparent"
                    border.color: "#4FBEF0"; border.width: 2
                }
            }

            // Nome
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: userModel.lastUser || "Herbert"
                color: "#4FBEF0"; font.pixelSize: 18; font.weight: Font.Medium
            }

            // Campo senha
            Rectangle {
                Layout.fillWidth: true; height: 40
                color: "#1a050008"
                border.color: passwordInput.activeFocus ? "#4FBEF0" : "#358AC7"
                border.width: 1; radius: 8

                TextInput {
                    id: passwordInput
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 10; bottomMargin: 10 }
                    echoMode: TextInput.Password
                    color: "#ffffff"; font.pixelSize: 14
                    verticalAlignment: TextInput.AlignVCenter
                    Text {
                        anchors.fill: parent
                        text: "Senha"; color: "#1E3E4Ad2"; font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter
                        visible: passwordInput.text.length === 0
                    }
                    Keys.onReturnPressed: doLogin()
                    Keys.onEnterPressed: doLogin()
                    Component.onCompleted: forceActiveFocus()
                }
            }

            // Sessão — ComboBox manual
            Item {
                id: sessionWrapper
                Layout.fillWidth: true
                height: 36

                property int sessionIndex: sessionModel.lastIndex
                property string sessionName: ""

                // Caixa principal
                Rectangle {
                    id: sessionBox
                    anchors.fill: parent
                    color: sessionBoxArea.containsMouse ? "#1E3E4Abf" : "#1a050008"
                    border.color: sessionDropdown.visible ? "#4FBEF0" : "#358AC7"
                    border.width: 1
                    radius: 8
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: arrowTxt.left; rightMargin: 4 }
                        text: sessionWrapper.sessionName
                        color: "#ffffff"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Text {
                        id: arrowTxt
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: sessionDropdown.visible ? "▲" : "▼"
                        color: "#ffffff"
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: sessionBoxArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sessionDropdown.visible = !sessionDropdown.visible
                    }
                }

                // Repeater oculto para ler nomes do sessionModel
                Repeater {
                    id: nameReader
                    model: sessionModel
                    delegate: Item {
                        width: 0; height: 0
                        visible: false
                        property string sName: model.name || ""
                        Component.onCompleted: {
                            if (index === sessionWrapper.sessionIndex)
                                sessionWrapper.sessionName = sName
                        }
                    }
                    onItemAdded: {
                        if (index === sessionWrapper.sessionIndex)
                            sessionWrapper.sessionName = itemAt(index) ? itemAt(index).sName : ""
                    }
                }

                // Dropdown visível
                Rectangle {
                    id: sessionDropdown
                    visible: false
                    parent: root
                    x: loginBox.x + 24
                    y: loginBox.y + sessionWrapper.mapToItem(loginBox, 0, 0).y + sessionWrapper.height + 4
                    width: loginBox.width - 48
                    height: Math.min(sessionModel.count * 36, 180)
                    color: "#1E3E4A"
                    border.color: "#4FBEF0"
                    border.width: 1
                    radius: 8
                    z: 100
                    clip: true

                    ListView {
                        anchors.fill: parent
                        model: sessionModel
                        clip: true
                        delegate: Rectangle {
                            width: sessionDropdown.width
                            height: 36
                            color: dArea.containsMouse ? "#33886dbf" : (sessionWrapper.sessionIndex === index ? "#22886dbf" : "transparent")
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                text: model.name || ""
                                color: "#ffffff"
                                font.pixelSize: 13
                            }
                            MouseArea {
                                id: dArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    sessionWrapper.sessionIndex = index
                                    sessionWrapper.sessionName = model.name || ""
                                    sessionDropdown.visible = false
                                }
                            }
                        }
                    }
                }
            }

            // Botão Entrar
            Rectangle {
                Layout.fillWidth: true; height: 40
                color: loginArea.pressed ? "#1B559Ebf" : loginArea.containsMouse ? "#1a886dbf" : "transparent"
                border.color: "#4FBEF0"; border.width: 1; radius: 8
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: "Entrar"; color: "#4FBEF0"; font.pixelSize: 14 }
                MouseArea {
                    id: loginArea; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: doLogin()
                }
            }

            // Erro
            Text {
                id: errorMsg
                Layout.fillWidth: true; text: ""; color: "#ff6b6b"
                font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap; visible: text !== ""
            }

            // Power buttons
            RowLayout {
                Layout.alignment: Qt.AlignHCenter; spacing: 24
                Repeater {
                    model: [
                        { icon: "⏾", tip: "Suspender", action: "suspend" },
                        { icon: "↺",  tip: "Reiniciar", action: "reboot" },
                        { icon: "⏻", tip: "Desligar",  action: "powerOff" }
                    ]
                    delegate: Text {
                        text: modelData.icon; font.pixelSize: 20
                        color: pArea.containsMouse ? "#4FBEF0" : "#1B559Ed2"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MouseArea {
                            id: pArea; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.action === "suspend")  sddm.suspend()
                                if (modelData.action === "reboot")   sddm.reboot()
                                if (modelData.action === "powerOff") sddm.powerOff()
                            }
                        }
                    }
                }
            }

            Item { height: 4 }
        }
    }

    function doLogin() {
        sddm.login(userModel.lastUser, passwordInput.text, sessionWrapper.sessionIndex)
    }

    // Relógio
    Column {
        anchors { top: parent.top; right: parent.right; margins: 24 }
        spacing: 4
        Text {
            id: clockLabel; anchors.right: parent.right
            color: "#ffffff"; font.pixelSize: 32; font.weight: Font.Light
            Timer { interval: 1000; repeat: true; running: true; onTriggered: clockLabel.text = Qt.formatTime(new Date(), "HH:mm") }
            Component.onCompleted: text = Qt.formatTime(new Date(), "HH:mm")
        }
        Text {
            anchors.right: parent.right; color: "#ffffffd2"; font.pixelSize: 14
            text: Qt.formatDate(new Date(), "dddd, dd 'de' MMMM")
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            errorMsg.text = "Senha incorreta"
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
        }
    }
}
