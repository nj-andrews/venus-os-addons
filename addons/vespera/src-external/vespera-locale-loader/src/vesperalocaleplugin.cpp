#include "vesperatranslator.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>

class VesperaLocalePlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char *uri) override
    {
        Q_ASSERT(QString::fromLatin1(uri) == QStringLiteral("Vespera"));
        qmlRegisterType<VesperaTranslator>(uri, 1, 0, "VesperaTranslator");
    }
};

#include "vesperalocaleplugin.moc"
