#include "vesperatranslator.h"

#include <QCoreApplication>
#include <QFileInfo>
#include <QDebug>

VesperaTranslator::VesperaTranslator(QObject *parent)
    : QObject(parent)
{
}

bool VesperaTranslator::loadLanguage(const QString &appName, const QString &langId)
{
    const QString normalizedAppName = appName.trimmed();
    const QString normalizedLangId = langId.trimmed().replace('-', '_');

    if (normalizedAppName.isEmpty() || normalizedLangId.isEmpty()) {
        qWarning() << "Missing app name or language ID for Vespera translation";
        return false;
    }

    const QString translationFilePath = QStringLiteral("/opt/victronenergy/gui/qml/%1/lang/%1_%2.qm")
        .arg(normalizedAppName, normalizedLangId);

    return loadTranslationFile(translationFilePath);
}

bool VesperaTranslator::loadTranslationFile(const QString &translationFilePath)
{
    const QString absolutePath = QFileInfo(translationFilePath).absoluteFilePath();
    if (absolutePath.isEmpty() || !QFileInfo::exists(absolutePath)) {
        qWarning() << "Vespera translation missing:" << absolutePath;
        return false;
    }

    auto *translator = new QTranslator(this);
    if (!translator->load(absolutePath)) {
        qWarning() << "Unable to load Vespera translation:" << absolutePath;
        delete translator;
        return false;
    }

    if (QCoreApplication::instance() != nullptr) {
        QCoreApplication::instance()->installTranslator(translator);
    }

    m_translators.append(translator);
    return true;
}
